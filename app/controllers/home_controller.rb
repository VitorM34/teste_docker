class HomeController < ApplicationController
  def index
   (1..5).to_a.each do |number|
    SendEmailJob.perform_later
   @message = "Container Carregado com Sucesso!"
   
    end
  end
end 