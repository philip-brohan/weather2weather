for i in {3..200}
do
python weather2weather.py \
  --mode train \
  --output_dir $SCRATCH/weather2weather/model_train.3days.$i \
  --max_epochs 1 \
  --input_dir $SCRATCH/weather2weather/p2p_format_images_for_training.3days \
  --which_direction AtoB \
  --checkpoint $SCRATCH/weather2weather/model_train.3days.$((i-1))
done
