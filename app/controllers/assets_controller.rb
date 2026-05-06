class AssetsController < ApplicationController
  before_action :restrict_request_format

  def show
    render json: { route: "show" }
  end

  def create
    render json: { route: "create" }
  end

  def update
    render json: { route: "update" }
  end

  def destroy
    render json: { route: "destroy" }
  end

  def restore
    render json: { route: "restore" }
  end

private

  def restrict_request_format
    request.format = :json
  end
end
