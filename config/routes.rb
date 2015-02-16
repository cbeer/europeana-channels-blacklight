Rails.application.routes.draw do
  root :to => "channels#index"

  blacklight_for :catalog, constraints: { id: /[^\/]+(\/|%2F)[^\/]+/ }
  resources :channels, only: [ :show, :index ]
  get '/records/:id', to: 'catalog#show', as: 'europeana_document', constraints: { id: /[^\/]+(\/|%2F)[^\/]+/ }
end
