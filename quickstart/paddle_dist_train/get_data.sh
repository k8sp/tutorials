#!/bin/bash

function get_data() {
  out_dir=${DATA_PATH}/${JOB_NAME}
  echo "using output dir ${out_dir}"
  echo "using split count ${TRAINER_COUNT}"
  mkdir -p $out_dir

  if [ -e $out_dir/.Done ]; then
    echo "Found .Done file, data preparation already finished, skipping..."
    exit 0
  fi

  printf "Downloading demo training data..."
  mkdir -p $out_dir/0/data
  cd $out_dir/0/data
  rm -rf *
  wget -q http://paddlepaddle.bj.bcebos.com/demo/quick_start_preprocessed_data/preprocessed_data.tar.gz
  tar zxvf preprocessed_data.tar.gz
  rm preprocessed_data.tar.gz
  echo "Done."

  printf "Spliting demo training data..."
  split -d --number=l/$TRAINER_COUNT -a 5 train.txt train.
  mv train.00000 train.txt

  cd $out_dir
  end=$(expr $TRAINER_COUNT - 1)
  for i in $(seq 1 $end); do
      echo $PWD
      mkdir -p $i/data
      cp -r 0/data/* $i/data
      mv $i/data/train.`printf %05d $i` $i/data/train.txt
  done;
  # mark data preparatioin is done
  touch $out_dir/.Done
  echo "Done."
}

get_data
