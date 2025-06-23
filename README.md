# Configuração de um container em Docker para aplicação em ruby

Aguns passos principais para a criação desse container

* Primeiro criar um novo projeto com rails new <nome do projeto > -d (banco de dados)

* vale ressaltar que nas versões do rails 7, a gem concurrent-ruby na versão 1.3.5 costuma dar erro no Logger
* usamos o gem uninstall concurrent-ruby, e com isso ele vai listar as versões que estão instaladas, e irá remover a versão 1.3.5
* No Gemfile, adicione o gem concurrent ruby 1.3.4 e rode bundle para definir ela como a versão correta
* ---------------------------------------------------------------------

# Colocando as configurações do container em Docker

* Primeiramente instale o docker desktop
* depois crie uma conta nele ou logue com a sua conta do github
* Agora abra o projeto no visual studio code
* abaixo estará o primeira configuracao do docker


```Docker
FROM ruby:3.4.3

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y \
    lsb-base \
    lsb-release \
    wget \
    curl \
    gnupg2 \
    build-essential \
    libpq-dev \
    vim \
    htop

RUN curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgresql-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/postgresql-archive-keyring.gpg] https://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" > /etc/apt/sources.list.d/pgdg.list

RUN apt-get update && apt-get install -y postgresql-client-16

RUN gem install pg

WORKDIR /home/app/web
COPY . .

RUN bundle install --jobs 5 --retry 5

CMD ["bash"]

```
* Acima são as configurações principais de um container docker.
  
> [!NOTE]
> UMA OBSERVAÇÃO A SER FEITA É QUE O DOCKERFILE E O DOCKER-COMPOSE.YML DEVEM ESTAR NA RAIZ DO PROJETO

-------------------------------

# Criando o docker-compose

* O arquivo docker-compose deve ter o .yml e tudo em minusculo
* O detalhe que esse dokcer-compose deve estar na raiz do projeto também

```
version: '3.8'  🔴 Versão do docker-compose

services:
  🔴 Serviço Redis (usado pelo Sidekiq para enfileirar jobs)
  redis:
    image: redis:latest          📍 Usa a imagem oficial mais recente do Redis
    ports:
      - "6379:6379"              📍 Mapeia a porta 6379 do container para a 6379 da máquina local

  🔴Serviço PostgreSQL (banco de dados usado pelo Rails)
  db:
    image: postgres:latest       📍Usa a imagem oficial mais recente do PostgreSQL
    environment:
      POSTGRES_USER: postgres    📍 Usuário padrão do Postgres
      POSTGRES_PASSWORD: postgres 📍 Senha do Postgres
    ports:
      - "5432:5432"              📍 Mapeia a porta 5432 do container para a 5432 local (padrão do Postgres)

  🔴 Serviço Web (Rails Server - Puma)
  web:
    build:
      context: .                 📍 Diretório onde está o Dockerfile (neste caso, a raiz do projeto)
      dockerfile: Dockerfile     📍 Nome do Dockerfile que o Compose usará
    command: bundle exec rails server -b 0.0.0.0 -p 3000  # Comando que inicia o servidor Rails
    volumes:
      - .:/app                   📍 Mapeia todo o projeto da máquina local para a pasta /app dentro do container
    ports:
      - "3000:3000"              📍 Porta 3000 do container exposta na porta 3000 local (Rails padrão)
    depends_on:
      - db                       📍 Garante que o container db suba antes deste
      - redis                    📍Garante que o redis também esteja disponível antes
    environment:
      DATABASE_URL: postgres://postgres:postgres@db:5432/postgres   📍 URL de conexão com o Postgres (o host é "db", o nome do serviço)
      REDIS_URL: redis://redis:6379/0                               📍 URL de conexão com o Redis (host "redis")

  🔴 Serviço Worker (Sidekiq - processador de jobs)
  worker:
    build:
      context: .                 📍 Mesmo Dockerfile da aplicação web
      dockerfile: Dockerfile
    command: bundle exec sidekiq -C config/sidekiq.yml  📍 Comando que inicializa o Sidekiq com a config YAML
    volumes:
      - .:/app                   📍Mapeia o código-fonte da máquina local para dentro do container
    depends_on:
      - db                       📍 Sidekiq precisa que o banco esteja pronto
      - redis                   📍 E precisa do Redis rodando
    environment:
      DATABASE_URL: postgres://postgres:postgres@db:5432/postgres  📍 Mesma conexão com o Postgres
      REDIS_URL: redis://redis:6379/0                              📍 Conexão com o Redis

```

# Instalando a gem sidkiq

**Passos para instalar a gem e qual sua funcionalidade**

Sidekiq é uma ferramenta de background jobs para aplicações Ruby on Rails (e outras aplicações Ruby).
Ela permite que você rode tarefas demoradas (como envio de e-mails, geração de relatórios, chamadas de API, etc) fora do fluxo da requisição web, sem travar seu app.


-------------

# Criando um arquivo setup_app.sh 

Serve para preparar o ambiente antes de iniciar o servidor Rails ou o Sidekiq, toda vez que o container sobe.

```
#! /bin/sh

🟢 Faz com que o script pare imediatamente se qualquer comando der erro
set -e 

🟢 (Comentado) Se você quiser instalar dependências JavaScript (se estiver usando Yarn)
# yarn install

🟢 Verifica se as gems já estão instaladas
🟢 Se não estiverem, roda o bundle install (instala as gems)
bundle check || bundle install --jobs 5 --retry 5

🟢 Se existir um arquivo antigo de PID (process ID) do servidor Rails, remove
🟢 Isso evita o erro "A server is already running" quando reiniciando o container
if [ -f tmp/pids/server.pid ]; then
  rm tmp/pids/server.pid
fi

🟢 Se o ambiente NÃO for desenvolvimento...
if [ "$RAILS_ENV" != development ]; then
  echo ' --> Running migrations'
  
  🟢 Executa as migrations do banco de dados (mantém schema atualizado)
  rails db:migrate
  
  echo ' --> End of migrations'
else
  🟢 Se for ambiente de desenvolvimento, pula as migrations (pra evitar travar o startup)
  echo ' --> Skip migrations for Dev env'
fi
```
# 🟣 Criando um arquivo .env.development para o redis

```
REDIS_URL=redis://redis:6379
DATABASE_URL=postgresql://postgres:password@db:5432/app_development
RAILS_ENV=development

```
# Criando uma pasta worker

Vale ressaltar que essa pasta é impotante para rodar o container

* Dentro de app crie uma pasta chamada de worker
* Dentro dela deve conter um arquivo entrypoint.sh e um Dockerfile
* as configuracoes desse docker serao parecidas com o nosso dockerfile da raiz, mas com algumas pequenas alterações.

# Dockerfile do worker
```
FROM ruby:3.4.3

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y \
    lsb-base \
    lsb-release \
    wget \
    curl \
    gnupg2 \
    build-essential \
    libpq-dev \
    vim \
    htop

# Instala chave do PostgreSQL
RUN curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgresql-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/postgresql-archive-keyring.gpg] https://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" > /etc/apt/sources.list.d/pgdg.list

RUN apt-get update && apt-get install -y postgresql-client-16

RUN gem install pg

WORKDIR /home/app/web

COPY . .

RUN bundle install --jobs 5 --retry 5

COPY app/worker/entrypoint.sh /home/app/web/entrypoint.sh
RUN chmod +x /home/app/web/entrypoint.sh

ENTRYPOINT ["/home/app/web/entrypoint.sh"]

```

# Arquivo entrypoint.sh 

lembrando que esse arquivo é essencial para que o projeto funcione

```
#! /bin/bash

set -e

sidekiq -c 1

```

# Criando uma view para teste

* dentro de app/views/layouts
* crie uma pasta worker, onde dentro deve conter o Dockerfile e o entrypoint.sh como descritos acima


-----------
# Configurando as rotas

dentro de routes rb vamos colocar os seguites dados, que estao marcados com o icone em vermelho

``` Ruby
🔺 require 'sidekiq/web'

Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
  🔺 get 'home', to: 'home#index'
 🔺 mount Sidekiq::Web => '/sidekiq'
end
```
# Criando um Job para teste

o arquivo do job será send_email_job.rb

``` ruby
class SendEmailJob < ApplicationJob
  queue_as :default

  def perform(*args)
    puts "===== Enviando Email ====="
    # Simula o envio de um email
    # Aqui você pode integrar com um serviço de envio de email real, como ActionMailer
    sleep 10
    puts "===== Email Enviado ====="
  end
end

```
# Criando um controller para Job

* Aqui criamos um controller, conforme o bloco abaixo
* O Controller esta como home_controller.rb, o mesmo gerado via terminal

``` ruby
class HomeController < ApplicationController
  def index
   (1..5).to_a.each do |number|
    SendEmailJob.perform_later
   @message = "Container Carregado com Sucesso!"
   
    end
  end
end 
```
# Criando o banco de dados

Depois de criar o container, vamos enfim construir nossa aplicação rails

* No terminal rode rails db:create
* Isso criara nosso banco de dados
* Com isso podemos definir do que será nosso projeto e seus objetivos
---------------------------------










