require "rqrcode"

class RoomsController < ApplicationController
  include RespectsStoreHours
  # The TV view (show, new) uses the dedicated tv layout; the phone
  # views (join, play) use the controller layout. before_action
  # resolves the layout per action.
  layout :layout_for_action

  before_action :load_room,         only: [:show, :join, :add_member, :play, :start]
  before_action :ensure_room_active, only: [:show, :join, :add_member, :play, :start]

  # GET /rooms/new — TV splash: "Press OK to create a room"
  def new
  end

  # POST /rooms — TV creates a room, redirects to show
  def create
    @room = Room.create!
    # Register the TV itself as the host membership so the lobby has an
    # obvious "host present" signal. Hosts don't get a slot (0 would
    # violate validation) — so hosts are outside the 1..4 slot range.
    # We model "host" as slot 0 by convention and skip the slot
    # validation for host memberships.
    session[:host_session_id] = host_session_id

    redirect_to room_path(code: @room.code)
  end

  # GET /rooms/:code — TV lobby / game display
  def show
    @qr_code_svg = RQRCode::QRCode.new(join_room_url(code: @room.code))
                                  .as_svg(color: "00ffc8", module_size: 6, standalone: true, use_path: true)
                                  .html_safe
    @games = Game.all
  end

  # GET /rooms/:code/join — phone landing page (name form)
  def join
    @membership = @room.memberships.find_by(session_id: phone_session_id)
    return redirect_to play_room_path(code: @room.code) if @membership
  end

  # POST /rooms/:code/join — phone submits a name
  def add_member
    if @room.full?
      @error = "Sorry, this room is full."
      return render :join, status: :unprocessable_entity
    end

    slot = @room.next_available_slot
    unless slot
      @error = "Sorry, this room is full."
      return render :join, status: :unprocessable_entity
    end

    @membership = @room.memberships.build(
      name:       params[:name],
      slot:       slot,
      role:       :player,
      session_id: phone_session_id,
      player:     current_player
    )

    if @membership.save
      @room.touch_expiry!
      RoomChannel.member_joined(@room, @membership)
      redirect_to play_room_path(code: @room.code)
    else
      @error = @membership.errors.full_messages.to_sentence
      render :join, status: :unprocessable_entity
    end
  end

  # GET /rooms/:code/play — phone controller shell (real thing in #4)
  def play
    @membership = @room.memberships.find_by(session_id: phone_session_id)
    return redirect_to join_room_path(code: @room.code) unless @membership
  end

  # POST /rooms/:code/start — host picks a game; broadcasts game_starting and
  # redirects the TV to the game page with ?room=<code> so the game wires
  # its key events to the ControllerChannel input stream.
  def start
    slug = params[:game_slug].to_s
    unless Score::GAME_SORT.key?(slug)
      @error = "Unknown game"
      return redirect_to room_path(code: @room.code), alert: @error
    end

    @room.update!(game_slug: slug, state: :playing)
    RoomChannel.game_starting(@room)

    redirect_to "/games/#{slug}.html?room=#{@room.code}",
                allow_other_host: false
  end

  private

  def layout_for_action
    case action_name
    when "new", "show", "start"                   then "tv"
    when "join", "add_member", "play"             then "controller"
    else "application"
    end
  end

  def load_room
    @room = Room.find_by(code: params[:code].to_s.upcase)
    raise ActionController::RoutingError, "Room not found" unless @room
  end

  def ensure_room_active
    if @room.expires_at <= Time.current
      raise ActionController::RoutingError, "Room has expired"
    end
  end

  # Stable per-browser id. Survives reloads but new browsers get a
  # fresh one, so rejoining from the same phone lands you back on
  # your existing membership.
  def phone_session_id
    session[:phone_session_id] ||= SecureRandom.hex(16)
  end

  def host_session_id
    session[:host_session_id] ||= SecureRandom.hex(16)
  end
end
