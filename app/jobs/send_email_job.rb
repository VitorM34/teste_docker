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
