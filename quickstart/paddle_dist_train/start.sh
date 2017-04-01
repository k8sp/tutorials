#!/bin/bash

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
    --use_gpu=1
}

function lock_or_done() {
  # IMPORTANT: Only one pod should do the data download job.
  out_dir=${JOB_PATH}"/"${JOB_NAME}
  mkdir -p $out_dir # mkdir is safe when doing mult-processes
  while [ true ]
  do
    echo "trying to get lock..."
    flock -x -w 5 $out_dir/.Filelock bash /root/get_data.sh
    if [ $? -eq 0 ]; then
      # Finished
      break
    else
      echo "waiting lock..."
      sleep 5
    fi
  done
  # ----------------- start train job -----------------
  start_train
  # ---------------- finish train job -----------------
}

lock_or_done
