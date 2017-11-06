# Forecast the weather using tensorflow and the pix2pix model.

Conditional Adversarial Networks offer a general machine learning tool to build a model deriving one (image) dataset from another. Originally demonstrated as a tool called [pix2pix](https://arxiv.org/pdf/1611.07004v1.pdf). Here I'm using a tensorflow port of this technique [pix2pix-tensorflow](https://github.com/affinelayer/pix2pix-tensorflow).

## The idea is to use pix2pix to transform an image describing the weather into an image describing the weather 6-hours later (a forecast).

First we need a tool to encode a surface weather field
  (2m air temperature anomaly, mean-sea-level-pressure, and precipitation rate)
  as an image. [Script](./weather2image//make.3var.plot.R)

Then we need a set of pairs of such images - a source image, and a target image from 6-hours later. Each pair should be separated by at least 5 days, so they are independent states. [Script](./weather2image//make.training.batch.R)

Then we need to take a training set (400) of those pairs of images and pack them into the 512x256 side-by-side format used by pix2pix (source in the left half, and target in the right half). [Script](./weather2image/make_p2p_training_images.R)

Alternatively, you can get the set of training and test images I used from [Dropbox](https://www.dropbox.com/s/0knxkll2btjjnyl/weather2weather_imgs.tar).

Then train a model on this set for 200 epochs - with a fast GPU this should take about 1 hour, but, CPU-only, it takes a bit over 24 hours on my 4-core iMac. (It took about 2 hours on one gpu-node of [Isambard](http://gw4.ac.uk/isambard/)

```sh
python weather2weather.py \
  --mode train \
  --output_dir $SCRATCH/weather2weather/model_train \
  --max_epochs 200 \
  --input_dir $SCRATCH/weather2weather/p2p_format_images_for_training \
  --which_direction AtoB
```
Now make some more pairs of images (100) to test the model on - same format as the training set, but must be different weather states (times). [Script](./weather2image/make_p2p_validation_images.R)

Use the trained model to make predictions from the validation set sources and compare those predictions to the validation set targets.

```sh
python weather2weather.py \
  --mode test \
  --output_dir $SCRATCH/weather2weather/model_test \
  --input_dir $SCRATCH/weather2weather/p2p_format_images_for_validation \
  --checkpoint $SCRATCH/weather2weather/model_train
```

The test run will output an HTML file at `$SCRATCH/weather2weather/model_test/index.html` that shows input/output/target image sets. This is good for a first glance, but those images are in a packed analysis form. So we need a tool to convert the packed image pairs to a clearer image format: [Script](./weather2image/replot.p2p.image.R). This shows target weather (top left), model output weather (top right), target pressure increment (bottom left), and model output pressure increment (bottom right).

To postprocess all the test cases run:
```sh
./weather2image/replot_all_validation.R \
  --input.dir=$SCRATCH/weather2weather/model_test/images \
  --output.dir=$SCRATCH/weather2weather/model_test/postprocessed
```

This will produce an HTML file at  `$SCRATCH/weather2weather/model_test/index.html` showing results of all the test cases.



## Acknowledgments
Derived from [pix2pix-tensorflow](https://github.com/affinelayer/pix2pix-tensorflow).

## Citation
Please cite the paper this code is based on: <a href="https://arxiv.org/pdf/1611.07004v1.pdf">Image-to-Image Translation Using Conditional Adversarial Networks</a>:

```
@article{pix2pix2016,
  title={Image-to-Image Translation with Conditional Adversarial Networks},
  author={Isola, Phillip and Zhu, Jun-Yan and Zhou, Tinghui and Efros, Alexei A},
  journal={arxiv},
  year={2016}
}
```
