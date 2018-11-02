from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

import tensorflow as tf
import numpy as np

import os

def setup(seed,mode,output_dir,checkpoint):
    if tf.__version__.split('.')[0] != "1":
        raise Exception("Tensorflow version 1 required")

    if seed is None:
        seed = random.randint(0, 2**31 - 1)

    tf.set_random_seed(seed)
    np.random.seed(seed)
    random.seed(seed)

    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    if mode == "test" or mode == "export":
        if checkpoint is None:
            raise Exception("checkpoint required for test mode")
        # load some options from the checkpoint
        options = {"which_direction", "ngf", "ndf", "lab_colorization"}
        with open(os.path.join(checkpoint, "options.json")) as f:
            for key, val in json.loads(f.read()).items():
                if key in options:
                    print("loaded", key, "=", val)
                    setattr(a, key, val)
        # disable these features in test mode
        scale_size = CROP_SIZE
        flip = False

        for k, v in a._get_kwargs():
        print(k, "=", v)

    with open(os.path.join(a.output_dir, "options.json"), "w") as f:
        f.write(json.dumps(vars(a), sort_keys=True, indent=4))



def export:
    
    # export the generator to a meta graph that can be imported later for standalone generation
    if a.lab_colorization:
        raise Exception("export not supported for lab_colorization")

    input = tf.placeholder(tf.string, shape=[1])
    input_data = tf.decode_base64(input[0])
    input_image = tf.image.decode_png(input_data)

    # remove alpha channel if present
    input_image = tf.cond(tf.equal(tf.shape(input_image)[2], 4), lambda: input_image[:,:,:3], lambda: input_image)
    # convert grayscale to RGB
    input_image = tf.cond(tf.equal(tf.shape(input_image)[2], 1), lambda: tf.image.grayscale_to_rgb(input_image), lambda: input_image)

    input_image = tf.image.convert_image_dtype(input_image, dtype=tf.float32)
    input_image.set_shape([CROP_SIZE, CROP_SIZE, 3])
    batch_input = tf.expand_dims(input_image, axis=0)

    with tf.variable_scope("generator"):
        batch_output = deprocess(create_generator(preprocess(batch_input), 3))

    output_image = tf.image.convert_image_dtype(batch_output, dtype=tf.uint8)[0]
    if a.output_filetype == "png":
        output_data = tf.image.encode_png(output_image)
    elif a.output_filetype == "jpeg":
        output_data = tf.image.encode_jpeg(output_image, quality=80)
    else:
        raise Exception("invalid filetype")
    output = tf.convert_to_tensor([tf.encode_base64(output_data)])

    key = tf.placeholder(tf.string, shape=[1])
    inputs = {
        "key": key.name,
        "input": input.name
    }
    tf.add_to_collection("inputs", json.dumps(inputs))
    outputs = {
        "key":  tf.identity(key).name,
        "output": output.name,
    }
    tf.add_to_collection("outputs", json.dumps(outputs))

    init_op = tf.global_variables_initializer()
    restore_saver = tf.train.Saver()
    export_saver = tf.train.Saver()

    with tf.Session() as sess:
        sess.run(init_op)
        print("loading model from checkpoint")
        checkpoint = tf.train.latest_checkpoint(a.checkpoint)
        restore_saver.restore(sess, checkpoint)
        print("exporting model")
        export_saver.export_meta_graph(filename=os.path.join(a.output_dir, "export.meta"))
        export_saver.save(sess, os.path.join(a.output_dir, "export"), write_meta_graph=False)
    return


# Image to 8-bit?
def convert(image):
    if a.aspect_ratio != 1.0:
        raise StandardError('Bad aspect ratio')
    return tf.image.convert_image_dtype(image, dtype=tf.uint8, saturate=True)

# Image processing steps?
def crunch_inputs(examples):
    inputs = deprocess(examples.inputs)
    targets = deprocess(examples.targets)
    outputs = deprocess(model.outputs)

    # reverse any processing on images so they can be written to disk or displayed to user
    with tf.name_scope("convert_inputs"):
        converted_inputs = convert(inputs)

    with tf.name_scope("convert_targets"):
        converted_targets = convert(targets)

    with tf.name_scope("convert_outputs"):
        converted_outputs = convert(outputs)

    return {'inputs':  inputs,
            'targets': targets.
            'outputs': outputs,
            'converted_inputs':  converted_inputs,
            'converted_outputs': converted_outputs,
            'converted_targets': converted_targets}

def summarise(model,crunched):
    
    # summaries
    with tf.name_scope("inputs_summary"):
        tf.summary.image("inputs",  crunched['converted_inputs'])

    with tf.name_scope("targets_summary"):
        tf.summary.image("targets", crunched['converted_targets'])

    with tf.name_scope("outputs_summary"):
        tf.summary.image("outputs", crunched['converted_outputs'])

    with tf.name_scope("predict_real_summary"):
        tf.summary.image("predict_real", tf.image.convert_image_dtype(model.predict_real, dtype=tf.uint8))

    with tf.name_scope("predict_fake_summary"):
        tf.summary.image("predict_fake", tf.image.convert_image_dtype(model.predict_fake, dtype=tf.uint8))

    tf.summary.scalar("discriminator_loss", model.discrim_loss)
    tf.summary.scalar("generator_loss_GAN", model.gen_loss_GAN)
    tf.summary.scalar("generator_loss_L1", model.gen_loss_L1)

    for var in tf.trainable_variables():
        tf.summary.histogram(var.op.name + "/values", var)

    for grad, var in model.discrim_grads_and_vars + model.gen_grads_and_vars:
        tf.summary.histogram(var.op.name + "/gradients", grad)

def test(sess,examples,max_steps,display_fetches):
    # testing
    # at most, process the test data once

    max_steps = min(examples.steps_per_epoch, max_steps)
    for step in range(max_steps):
        results = sess.run(display_fetches)
        filesets = save_images(results)
        for i, f in enumerate(filesets):
            print("evaluated image", f["name"])
        index_path = append_index(filesets)

    print("wrote index at", index_path)

def train(max_steps,trace_freq,model,summary_freq,display_freq,sess,sv,options,run_metadata,
          batch_size,save_freq,output_dir,saver):
    
    # training
    start = time.time()

    for step in range(max_steps):
        def should(freq):
            return freq > 0 and ((step + 1) % freq == 0 or step == max_steps - 1)

        options = None
        run_metadata = None
        if should(a.trace_freq):
            options = tf.RunOptions(trace_level=tf.RunOptions.FULL_TRACE)
            run_metadata = tf.RunMetadata()

        fetches = {
            "train": model.train,
            "global_step": sv.global_step,
        }

        if should(a.progress_freq):
            fetches["discrim_loss"] = model.discrim_loss
            fetches["gen_loss_GAN"] = model.gen_loss_GAN
            fetches["gen_loss_L1"] = model.gen_loss_L1

        if should(a.summary_freq):
            fetches["summary"] = sv.summary_op

        if should(a.display_freq):
            fetches["display"] = display_fetches

        results = sess.run(fetches, options=options, run_metadata=run_metadata)

        if should(a.summary_freq):
            print("recording summary")
            sv.summary_writer.add_summary(results["summary"], results["global_step"])

        if should(a.display_freq):
            print("saving display images")
            filesets = save_images(results["display"], step=results["global_step"])
            append_index(filesets, step=True)

        if should(a.trace_freq):
            print("recording trace")
            sv.summary_writer.add_run_metadata(run_metadata, "step_%d" % results["global_step"])

        if should(a.progress_freq):
            # global_step will have the correct step count if we resume from a checkpoint
            train_epoch = math.ceil(results["global_step"] / examples.steps_per_epoch)
            train_step = (results["global_step"] - 1) % examples.steps_per_epoch + 1
            rate = (step + 1) * a.batch_size / (time.time() - start)
            remaining = (max_steps - step) * a.batch_size / rate
            print("progress  epoch %d  step %d  image/sec %0.1f  remaining %dm" % (train_epoch, train_step, rate, remaining / 60))
            print("discrim_loss", results["discrim_loss"])
            print("gen_loss_GAN", results["gen_loss_GAN"])
            print("gen_loss_L1", results["gen_loss_L1"])

        if should(a.save_freq):
            print("saving model")
            saver.save(sess, os.path.join(a.output_dir, "model"), global_step=sv.global_step)

        if sv.should_stop():
            break


def main():

    if a.mode == "export":
        export()
        return

    examples = load_examples()
    print("examples count = %d" % examples.count)

    # inputs and targets are [batch_size, height, width, channels]
    model = create_model(examples.inputs, examples.targets)

    # What is going on here?
    crunched=crunch_inputs(examples)

    # ???
    with tf.name_scope("encode_images"):
        display_fetches = {
            "paths": examples.paths,
            "inputs":  tf.map_fn(tf.image.encode_png, crunched['converted_inputs'],  dtype=tf.string, name="input_pngs"),
            "targets": tf.map_fn(tf.image.encode_png, crunched['converted_targets'], dtype=tf.string, name="target_pngs"),
            "outputs": tf.map_fn(tf.image.encode_png, crunched['converted_outputs'], dtype=tf.string, name="output_pngs"),
        }

    # output summaries
    summarise(model,crunched)
        
    with tf.name_scope("parameter_count"):
        parameter_count = tf.reduce_sum([tf.reduce_prod(tf.shape(v)) for v in tf.trainable_variables()])

    saver = tf.train.Saver(max_to_keep=1)

    logdir = a.output_dir if (a.trace_freq > 0 or a.summary_freq > 0) else None
    sv = tf.train.Supervisor(logdir=logdir, save_summaries_secs=0, saver=None)
    with sv.managed_session() as sess:
        print("parameter_count =", sess.run(parameter_count))

        if a.checkpoint is not None:
            print("loading model from checkpoint")
            checkpoint = tf.train.latest_checkpoint(a.checkpoint)
            saver.restore(sess, checkpoint)

        max_steps = 2**32
        if a.max_epochs is not None:
            max_steps = examples.steps_per_epoch * a.max_epochs
        if a.max_steps is not None:
            max_steps = a.max_steps

        if a.mode == "test":
            test(sess,examples,max_steps,display_fetches)
        else:
            train(max_steps,trace_freq,model,summary_freq,display_freq,sess,sv,options,run_metadata,
                  batch_size,save_freq,output_dir,saver)
