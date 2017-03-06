FROM paddledev/paddle:cpu-latest

RUN apk update && apk upgrade && apk add coreutils
ADD start.sh start_paddle.py get_data.sh /root/
CMD ["bash","/root/start.sh"]
