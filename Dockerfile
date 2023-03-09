FROM wordpress:latest
ENV WORDPRESS_DB_HOST=my-rds-instance.xxxxxxxxxxxx.us-east-1.rds.amazonaws.com
ENV WORDPRESS_DB_USER=bronze
ENV WORDPRESS_DB_PASSWORD=Password1234
ENV WORDPRESS_DB_NAME=wordpress
EXPOSE 80