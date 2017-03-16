FROM paddledev/paddle:cpu-latest

RUN sed 's@http:\/\/archive.ubuntu.com\/ubuntu\/@mirror:\/\/mirrors.ubuntu.com\/mirrors.txt@' -i /etc/apt/sources.list && \
apt-get update && apt-get -y install wget
ADD start.sh start_paddle.py get_data.sh /root/
CMD ["bash","/root/start.sh"]
