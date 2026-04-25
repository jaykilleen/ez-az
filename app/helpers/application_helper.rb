module ApplicationHelper
  def game_icon_svg(icon)
    case icon
    when "rocket"
      rocket_icon
    when "dodgeball"
      dodgeball_icon
    when "zombie"
      zombie_icon
    when "maze"
      maze_icon
    when "cat"
      cat_icon
    when "bloom"
      bloom_icon
    when "trivia"
      trivia_icon
    else
      placeholder_icon
    end
  end

  private

  def rocket_icon
    <<~SVG.html_safe
      <svg class="icon-svg" viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <radialGradient id="stars-bg" cx="50%" cy="50%">
            <stop offset="0%" stop-color="#1a1a3e"/>
            <stop offset="100%" stop-color="#050515"/>
          </radialGradient>
        </defs>
        <rect width="100" height="100" fill="url(#stars-bg)"/>
        <circle cx="15" cy="20" r="0.8" fill="#fff"/>
        <circle cx="85" cy="15" r="0.6" fill="#fff"/>
        <circle cx="78" cy="80" r="0.8" fill="#fff"/>
        <circle cx="20" cy="75" r="0.6" fill="#fff"/>
        <circle cx="50" cy="10" r="1" fill="#00ffc8"/>
        <circle cx="92" cy="50" r="0.7" fill="#fff"/>
        <!-- Rocket body -->
        <path d="M 50 25 L 42 55 L 58 55 Z" fill="#e0e0ff"/>
        <rect x="42" y="55" width="16" height="20" fill="#c0c0e0"/>
        <!-- Window -->
        <circle cx="50" cy="45" r="5" fill="#00ffc8"/>
        <!-- Fins -->
        <path d="M 42 65 L 32 80 L 42 75 Z" fill="#ff00aa"/>
        <path d="M 58 65 L 68 80 L 58 75 Z" fill="#ff00aa"/>
        <!-- Flame -->
        <path d="M 44 75 L 50 92 L 56 75 Z" fill="#ffc107"/>
        <path d="M 46 75 L 50 85 L 54 75 Z" fill="#ff5722"/>
      </svg>
    SVG
  end

  def dodgeball_icon
    <<~SVG.html_safe
      <svg class="icon-svg" viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
        <rect width="100" height="100" fill="#1a4020"/>
        <!-- Court lines -->
        <rect x="10" y="10" width="80" height="80" fill="none" stroke="#ffeb3b" stroke-width="1.5"/>
        <line x1="50" y1="10" x2="50" y2="90" stroke="#ffeb3b" stroke-width="1.5"/>
        <!-- Ball -->
        <circle cx="50" cy="50" r="12" fill="#ff5252"/>
        <path d="M 50 38 Q 40 50 50 62" stroke="#fff" stroke-width="1.5" fill="none"/>
        <path d="M 50 38 Q 60 50 50 62" stroke="#fff" stroke-width="1.5" fill="none"/>
        <!-- Players -->
        <circle cx="25" cy="35" r="5" fill="#2196f3"/>
        <rect x="21" y="40" width="8" height="10" fill="#2196f3"/>
        <circle cx="25" cy="65" r="5" fill="#2196f3"/>
        <rect x="21" y="70" width="8" height="10" fill="#2196f3"/>
        <circle cx="75" cy="35" r="5" fill="#e91e63"/>
        <rect x="71" y="40" width="8" height="10" fill="#e91e63"/>
        <circle cx="75" cy="65" r="5" fill="#e91e63"/>
        <rect x="71" y="70" width="8" height="10" fill="#e91e63"/>
      </svg>
    SVG
  end

  def zombie_icon
    <<~SVG.html_safe
      <svg class="icon-svg" viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <linearGradient id="z-bg" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stop-color="#2e1a3e"/>
            <stop offset="100%" stop-color="#0a0515"/>
          </linearGradient>
        </defs>
        <rect width="100" height="100" fill="url(#z-bg)"/>
        <!-- Fog -->
        <ellipse cx="50" cy="85" rx="40" ry="6" fill="#4a3a5a" opacity="0.6"/>
        <!-- Zombie body -->
        <ellipse cx="50" cy="80" rx="15" ry="8" fill="#4a7c3a"/>
        <rect x="38" y="55" width="24" height="30" fill="#5a8c4a"/>
        <!-- Head -->
        <ellipse cx="50" cy="40" rx="16" ry="18" fill="#6a9c5a"/>
        <!-- Cuts -->
        <path d="M 42 35 L 46 40" stroke="#3a5c2a" stroke-width="2"/>
        <path d="M 55 45 L 60 42" stroke="#3a5c2a" stroke-width="2"/>
        <!-- Eyes -->
        <circle cx="44" cy="38" r="3" fill="#ff2200"/>
        <circle cx="56" cy="38" r="3" fill="#ff2200"/>
        <circle cx="44" cy="38" r="1" fill="#fff"/>
        <circle cx="56" cy="38" r="1" fill="#fff"/>
        <!-- Mouth -->
        <path d="M 42 48 L 46 52 L 50 48 L 54 52 L 58 48" stroke="#2a1a1a" stroke-width="2" fill="none"/>
        <!-- Arms outstretched -->
        <rect x="22" y="60" width="18" height="5" fill="#5a8c4a" transform="rotate(-10 30 62)"/>
        <rect x="60" y="60" width="18" height="5" fill="#5a8c4a" transform="rotate(10 70 62)"/>
      </svg>
    SVG
  end

  def maze_icon
    <<~SVG.html_safe
      <svg class="icon-svg" viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
        <rect width="100" height="100" fill="#0a0a18"/>
        <!-- Maze walls -->
        <g stroke="#2a3a5a" stroke-width="3" fill="none">
          <path d="M 10 10 L 90 10 L 90 30 L 30 30 L 30 50 L 70 50 L 70 70 L 20 70 L 20 90 L 90 90"/>
          <path d="M 10 30 L 10 90"/>
          <path d="M 50 30 L 50 50"/>
          <path d="M 50 70 L 50 90"/>
        </g>
        <!-- Flashlight cone -->
        <defs>
          <radialGradient id="torch" cx="50%" cy="50%">
            <stop offset="0%" stop-color="#ffeb3b" stop-opacity="0.8"/>
            <stop offset="40%" stop-color="#ffc107" stop-opacity="0.3"/>
            <stop offset="100%" stop-color="#ffc107" stop-opacity="0"/>
          </radialGradient>
        </defs>
        <circle cx="50" cy="60" r="25" fill="url(#torch)"/>
        <!-- Dino character -->
        <ellipse cx="50" cy="65" rx="7" ry="5" fill="#4caf50"/>
        <ellipse cx="50" cy="58" rx="6" ry="6" fill="#66bb6a"/>
        <circle cx="48" cy="57" r="1.5" fill="#000"/>
        <circle cx="52" cy="57" r="1.5" fill="#000"/>
      </svg>
    SVG
  end

  def cat_icon
    <<~SVG.html_safe
      <svg class="icon-svg" viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
        <rect width="100" height="100" fill="#ffe4b5"/>
        <!-- Ground -->
        <rect y="80" width="100" height="20" fill="#d2b48c"/>
        <!-- Pegs -->
        <circle cx="30" cy="40" r="3" fill="#8b4513"/>
        <circle cx="60" cy="30" r="3" fill="#8b4513"/>
        <circle cx="75" cy="55" r="3" fill="#8b4513"/>
        <!-- Rope -->
        <path d="M 20 20 Q 30 40 60 30 Q 75 45 75 55" stroke="#654321" stroke-width="2" fill="none"/>
        <!-- Cat -->
        <ellipse cx="18" cy="25" rx="8" ry="6" fill="#ff9800"/>
        <polygon points="12,22 10,16 15,20" fill="#ff9800"/>
        <polygon points="24,22 26,16 21,20" fill="#ff9800"/>
        <circle cx="15" cy="25" r="1" fill="#000"/>
        <circle cx="20" cy="25" r="1" fill="#000"/>
        <path d="M 15 28 Q 18 30 21 28" stroke="#000" stroke-width="0.8" fill="none"/>
        <!-- Mouse -->
        <ellipse cx="82" cy="75" rx="6" ry="4" fill="#9e9e9e"/>
        <circle cx="78" cy="73" r="2" fill="#9e9e9e"/>
        <circle cx="77" cy="73" r="0.8" fill="#000"/>
        <path d="M 88 75 Q 95 75 95 80" stroke="#9e9e9e" stroke-width="1" fill="none"/>
      </svg>
    SVG
  end

  def bloom_icon
    <<~SVG.html_safe
      <svg class="icon-svg" viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <linearGradient id="b-bg" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stop-color="#ffecb3"/>
            <stop offset="100%" stop-color="#ffcc80"/>
          </linearGradient>
        </defs>
        <rect width="100" height="100" fill="url(#b-bg)"/>
        <!-- Sun -->
        <circle cx="80" cy="20" r="10" fill="#ffeb3b"/>
        <!-- Grass -->
        <rect y="75" width="100" height="25" fill="#8bc34a"/>
        <!-- Flower stem -->
        <line x1="50" y1="75" x2="50" y2="55" stroke="#558b2f" stroke-width="3"/>
        <!-- Petals -->
        <circle cx="50" cy="42" r="8" fill="#ff4081"/>
        <circle cx="42" cy="48" r="8" fill="#e91e63"/>
        <circle cx="58" cy="48" r="8" fill="#e91e63"/>
        <circle cx="46" cy="38" r="8" fill="#f06292"/>
        <circle cx="54" cy="38" r="8" fill="#f06292"/>
        <circle cx="50" cy="45" r="5" fill="#ffeb3b"/>
        <!-- Small flowers -->
        <circle cx="20" cy="82" r="3" fill="#fff"/>
        <circle cx="20" cy="82" r="1" fill="#ffeb3b"/>
        <circle cx="80" cy="85" r="3" fill="#fff"/>
        <circle cx="80" cy="85" r="1" fill="#ffeb3b"/>
      </svg>
    SVG
  end

  def trivia_icon
    <<~SVG.html_safe
      <svg class="icon-svg" viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <linearGradient id="tq-bg" x1="0" y1="0" x2="1" y2="1">
            <stop offset="0%" stop-color="#0d1b2a"/>
            <stop offset="100%" stop-color="#1a1a3e"/>
          </linearGradient>
        </defs>
        <rect width="100" height="100" fill="url(#tq-bg)" rx="8"/>
        <!-- Question mark large -->
        <text x="50" y="58" text-anchor="middle" fill="#00ffc8" font-size="54" font-family="Georgia,serif" font-weight="bold">?</text>
        <!-- Small coloured dots (players) -->
        <circle cx="22" cy="82" r="7" fill="#ff4757"/>
        <circle cx="40" cy="82" r="7" fill="#3742fa"/>
        <circle cx="60" cy="82" r="7" fill="#ffa502"/>
        <circle cx="78" cy="82" r="7" fill="#2ed573"/>
        <!-- Buzz lines -->
        <line x1="10" y1="30" x2="20" y2="30" stroke="#ffd700" stroke-width="2.5" stroke-linecap="round"/>
        <line x1="80" y1="30" x2="90" y2="30" stroke="#ffd700" stroke-width="2.5" stroke-linecap="round"/>
        <line x1="15" y1="22" x2="21" y2="28" stroke="#ffd700" stroke-width="2.5" stroke-linecap="round"/>
        <line x1="85" y1="22" x2="79" y2="28" stroke="#ffd700" stroke-width="2.5" stroke-linecap="round"/>
      </svg>
    SVG
  end

  def placeholder_icon
    <<~SVG.html_safe
      <svg class="icon-svg" viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
        <rect width="100" height="100" fill="#1a1a2e"/>
        <text x="50" y="55" text-anchor="middle" fill="#00ffc8" font-size="30" font-family="monospace">?</text>
      </svg>
    SVG
  end
end
