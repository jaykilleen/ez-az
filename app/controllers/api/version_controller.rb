module Api
  class VersionController < BaseController
    def show
      render json: { version: EzAz::Version::STRING, commit: EzAz::Version::COMMIT }
    end
  end
end
