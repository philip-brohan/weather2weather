for i in {1..200}
do
python weather2weather.py \
  --mode test \
  --output_dir $SCRATCH/weather2weather/model_test.3days.$i \
  --input_dir $SCRATCH/weather2weather/p2p_format_images_for_validation.3days \
  --checkpoint $SCRATCH/weather2weather/model_train.3days.$i
done
