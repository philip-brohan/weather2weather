from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

import argparse

def getOptions():
    parser = argparse.ArgumentParser()

    # Choose what to do
    parser.add_argument("--mode",
                        required=True,
                        choices=["train", "test", "export"])
    parser.add_argument("--which_direction",
                        type=str,
                        default="AtoB",
                        choices=["AtoB", "BtoA"])
    # Important controls
    parser.add_argument("--max_steps",
                        type=int,
                        help="number of training steps (0 to disable)")
    parser.add_argument("--max_epochs",
                        type=int,
                        help="number of training epochs")
    parser.add_argument("--batch_size",
                        type=int,
                        default=1,
                        help="number of inputs in batch")

    # Model specification
    parser.add_argument("--ngf",
                        type=int,
                        default=64,
                        help="number of generator filters in first conv layer")
    parser.add_argument("--ndf",
                        type=int,
                        default=64,
                        help="number of discriminator filters in first conv layer")
    
    # Path options
    parser.add_argument("--input_dir",
                        help="path to folder containing imputs")
    parser.add_argument("--output_dir",
                        required=True, help="where to put output files")
    parser.add_argument("--checkpoint",
                        default=None,
                        help="directory with checkpoint to resume from")

    # Output options
    parser.add_argument("--summary_freq",
                        type=int,
                        default=100,
                        help="update summaries every summary_freq steps")
    parser.add_argument("--progress_freq",
                        type=int,
                        default=50,
                        help="display progress every progress_freq steps")
    parser.add_argument("--trace_freq",
                        type=int,
                        default=0,
                        help="trace execution every trace_freq steps")
    parser.add_argument("--display_freq",
                        type=int,
                        default=0,
                        help="write current training images every display_freq steps")
    parser.add_argument("--save_freq",
                        type=int,
                        default=5000,
                        help="save model every save_freq steps, 0 to disable")

    # Details
    parser.add_argument("--seed",
                        type=int)
    parser.add_argument("--lr",
                        type=float,
                        default=0.0002,
                        help="initial learning rate for adam")
    parser.add_argument("--beta1",
                        type=float,
                        default=0.5,
                        help="momentum term of adam")
    parser.add_argument("--l1_weight",
                        type=float,
                        default=100.0,
                        help="weight on L1 term for generator gradient")
    parser.add_argument("--gan_weight",
                        type=float,
                        default=1.0,
                        help="weight on GAN term for generator gradient")

    a = parser.parse_args()

    return(a)
