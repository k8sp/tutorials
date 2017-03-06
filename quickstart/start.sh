#!/bin/bash

set -eu

function get_data() {
  out_dir=${JOB_PATH}"/"${JOB_NAME}
  split_count=$SPLIT_COUNT
  echo "using output dir ${out_dir}"
  echo "using split count ${split_count}"

  mkdir -p $out_dir
  printf "Cloning PaddlePaddle master branch..."
  git clone -b master https://github.com/PaddlePaddle/Paddle.git paddle
  cp -r paddle/demo/quick_start $out_dir/
  echo "Done."

  printf "Downloading demo training data..."
  mkdir -p $out_dir/0/data
  cd $out_dir/0/data
  rm -rf *
  wget http://paddlepaddle.bj.bcebos.com/demo/quick_start_preprocessed_data/preprocessed_data.tar.gz
  tar zxvf preprocessed_data.tar.gz
  rm preprocessed_data.tar.gz
  echo "Done."

  printf "Spliting demo training data..."
  split -d --number=l/$split_count -a 5 train.txt train.
  mv train.00000 train.txt

  cd $out_dir
  end=$(expr $split_count - 1)
  for i in $(seq 1 $end); do
      mkdir -p $i/data
      cp -r 0/data/* $i/data
      mv $i/data/train.`printf %05d $i` $i/data/train.txt
  done;
  echo "Done."
}

function start_train() {
  jobconfig=${JOB_PATH}"/"${JOB_NAME}"/"${TRAIN_CONFIG_DIR}
  cd /root
  cp -rf $jobconfig/* .

  python /root/start_paddle.py \
    --dot_period=10 \
    --ports_num=$CONF_PADDLE_PORTS_NUM \
    --ports_num_for_sparse=$CONF_PADDLE_PORTS_NUM_SPARSE \
    --log_period=50 \
    --num_passes=10 \
    --trainer_count=$TRAINER_COUNT \
    --saving_period=1 \
    --local=0 \
    --config=trainer_config.lr.py \
    --use_gpu=0
}

get_data && \
start_train
