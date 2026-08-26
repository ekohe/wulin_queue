# Drawn into the host application, not into the engine — the engine is never
# mounted, exactly like wulin_audit. Screens live in the host's URL space so
# they share its layout, login and menu.
#
# `run_now` rather than `dispatch`: ActionController::Metal already defines an
# instance method called `dispatch`, and overriding it breaks request handling.
Rails.application.routes.draw do
  namespace :wulin_queue do
    resources :jobs, only: :index do
      collection do
        post :discard
        post :retry
        post :retry_all
      end
    end

    resources :queues, only: :index do
      collection do
        post :pause
        post :resume
        post :clear
      end
    end

    resources :processes, only: :index

    resources :recurring_tasks, only: :index do
      post :run_now, on: :collection
    end
  end
end
