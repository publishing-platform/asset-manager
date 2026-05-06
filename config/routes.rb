Rails.application.routes.draw do
  resources :assets, only: %i[show create update destroy] do
    member do
      post :restore
    end
  end

  get "/media/:id/:filename" => "media#download", :constraints => { filename: /.*/ }, as: :download_media

  get "/healthcheck/live", to: proc { [200, {}, %w[OK]] }
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
end
