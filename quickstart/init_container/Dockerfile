FROM paddledev/paddle:cpu-latest

RUN apt-get update && apt-get install wget
ADD get_data.sh /root/
CMD ["bash","/root/get_data.sh"]
