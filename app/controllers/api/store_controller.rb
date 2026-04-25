class Api::StoreController < ApplicationController
  def status
    response.headers["Cache-Control"] = "no-store"
    open_until = Counter.find_by(key: "store_open_until")&.value
    override   = open_until && open_until > Time.now.to_i
    render json: { override: !!override, open_until: override ? open_until : nil }
  end
end
