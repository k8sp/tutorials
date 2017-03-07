FROM paddledev/paddle:cpu-latest

RUN apt-get update && apt-get install wget
ADD start.sh start_paddle.py /root/
CMD ["bash","/root/start.sh"]
