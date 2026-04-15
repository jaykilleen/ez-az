counter_file = Rails.root.join("data", "counter.json")
saved_count = counter_file.exist? ? (JSON.parse(counter_file.read)["count"].to_i rescue 0) : 0

Counter.find_or_create_by!(key: "visitors") do |c|
  c.value = saved_count
end
