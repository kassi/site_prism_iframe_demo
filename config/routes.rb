Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  root to: "page#index"
  namespace :payments do
    resource :payment_method, only: [:edit]
  end
end
