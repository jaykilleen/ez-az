Counter.find_or_create_by!(key: "visitors") { |c| c.value = 0 }
