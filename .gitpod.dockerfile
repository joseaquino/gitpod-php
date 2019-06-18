FROM buildpack-deps:cosmic

### base ###
RUN yes | unminimize \
    && apt-get install -yq \
        asciidoctor \
        bash-completion \
        build-essential \
        htop \
        jq \
        less \
        locales \
        man-db \
        nano \
        software-properties-common \
        sudo \
        vim \
        multitail \
    && locale-gen en_US.UTF-8 \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/*
ENV LANG=en_US.UTF-8

### Gitpod user ###
# '-l': see https://docs.docker.com/develop/develop-images/dockerfile_best-practices/#user
RUN useradd -l -u 33333 -G sudo -md /home/logikode -s /bin/bash -p logikode logikode \
    # passwordless sudo for users in the 'sudo' group
    && sed -i.bkp -e 's/%sudo\s\+ALL=(ALL\(:ALL\)\?)\s\+ALL/%sudo ALL=NOPASSWD:ALL/g' /etc/sudoers
ENV HOME=/home/logikode
WORKDIR $HOME
# custom Bash prompt
RUN { echo && echo "PS1='\[\e]0;\u \w\a\]\[\033[01;32m\]\u\[\033[00m\] \[\033[01;34m\]\w\[\033[00m\] \\\$ '" ; } >> .bashrc

### Apache and Nginx ###

RUN apt-get update && apt-get install -yq \
        apache2 \
        nginx \
        nginx-extras \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* \
    && mkdir /var/run/apache2 \
    && mkdir /var/lock/apache2 \
    && mkdir /var/run/nginx \
    && ln -s /etc/apache2/mods-available/rewrite.load /etc/apache2/mods-enabled/rewrite.load \
    && chown -R logikode:logikode /etc/apache2 /var/run/apache2 /var/lock/apache2 /var/log/apache2 \
    && chown -R logikode:logikode /etc/nginx /var/run/nginx /var/lib/nginx/ /var/log/nginx/
COPY apache2/ /etc/apache2/
COPY nginx /etc/nginx/

## The directory relative to your git repository that will be served by Apache / Nginx
ENV APACHE_DOCROOT_IN_REPO="public"
ENV NGINX_DOCROOT_IN_REPO="public"


### PHP ###
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -yq \
        composer \
        php \
        php-all-dev \
        php-ctype \
        php-curl \
        php-date \
        php-gd \
        php-gettext \
        php-intl \
        php-json \
        php-mbstring \
        php-mysql \
        php-net-ftp \
        php-pgsql \
        php-sqlite3 \
        php-tokenizer \
        php-xml \
        php-zip \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/*
# PHP language server is installed by theia-php-extension

### Gitpod user (2) ###
USER logikode
# use sudo so that user does not get sudo usage info on (the first) login
RUN sudo echo "Running 'sudo' for Logikode: success"

### Node.js ###
ARG NODE_VERSION=10.15.3
RUN curl -fsSL https://raw.githubusercontent.com/creationix/nvm/v0.34.0/install.sh | bash \
    && bash -c ". .nvm/nvm.sh \
        && nvm install $NODE_VERSION \
        && npm config set python /usr/bin/python --global \
        && npm config set python /usr/bin/python \
        && npm install -g typescript yarn"
ENV PATH=/home/gitpod/.nvm/versions/node/v${NODE_VERSION}/bin:$PATH

### Python ###
ENV PATH=$HOME/.pyenv/bin:$HOME/.pyenv/shims:$PATH
RUN curl -fsSL https://github.com/pyenv/pyenv-installer/raw/master/bin/pyenv-installer | bash \
    && { echo; \
        echo 'eval "$(pyenv init -)"'; \
        echo 'eval "$(pyenv virtualenv-init -)"'; } >> .bashrc \
    && pyenv install 2.7.15 \
    && pyenv install 3.7.2 \
    && pyenv global 2.7.15 3.7.2 \
    && pip2 install --upgrade pip \
    && pip2 install virtualenv pipenv pylint rope flake8 autopep8 pep8 pylama pydocstyle bandit python-language-server[all]==0.25.0 \
    && pip3 install --upgrade pip \
    && pip3 install virtualenv pipenv pylint rope flake8 autopep8 pep8 pylama pydocstyle bandit python-language-server[all]==0.25.0 \
    && rm -rf /tmp/*
# Gitpod will automatically add user site under `/workspace` to persist your packages.
# ENV PYTHONUSERBASE=/workspace/.pip-modules \
#    PIP_USER=yes

### checks ###
# no root-owned files in the home directory
RUN notOwnedFile=$(find . -not "(" -user logikode -and -group logikode ")" -print -quit) \
    && { [ -z "$notOwnedFile" ] \
        || { echo "Error: not all files/dirs in $HOME are owned by 'logikode' user & group"; exit 1; } }
