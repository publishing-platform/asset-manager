# frozen_string_literal: true

class MediaController < ApplicationController
  def download
    render json: { route: "download" }
  end
end
