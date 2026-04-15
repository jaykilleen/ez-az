module Api
  class VersionController < ApplicationController
    def show
      render json: { version: EzAz::Version::STRING, commit: EzAz::Version::COMMIT }
    end
  end
end
