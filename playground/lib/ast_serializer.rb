module AstSerializer
  module_function

  def serialize(node)
    return nil if node.nil?

    type = node.class.name.split("::").last
    props = clean_properties(node, type)
    children = (node.children || []).map { |c| serialize(c) }.compact

    result = { type: type, properties: props }
    result[:children] = children unless children.empty?

    if node.respond_to?(:effects) && node.effects&.any?
      result[:effects] = node.effects.map { |e| serialize(e) }.compact
    end

    result
  end

  def deep_clone(node)
    Marshal.load(Marshal.dump(node))
  end

  def diff(pre, post)
    pre_ids = collect_nodes(pre)
    post_ids = collect_nodes(post)

    removed = pre_ids - post_ids
    { removed_count: removed.size, removed: removed }
  end

  def clean_properties(node, type)
    props = {}

    case type
    when "Canvas"
      props[:width] = node.width if node.respond_to?(:width)
      props[:height] = node.height if node.respond_to?(:height)
    when "Layer"
      props[:source] = node.source if node.respond_to?(:source) && node.source
      props[:solid] = node.properties[:solid] if node.properties[:solid]
      props[:text] = node.properties[:text] if node.properties[:text]
      props[:gradient] = node.properties[:gradient].to_s if node.properties[:gradient]
      props[:x] = node.x if node.respond_to?(:x) && node.x && node.x != 0
      props[:y] = node.y if node.respond_to?(:y) && node.y && node.y != 0
      props[:width] = node.width if node.respond_to?(:width) && node.width
      props[:height] = node.height if node.respond_to?(:height) && node.height
      props[:blend] = node.properties[:blend] if node.properties[:blend]
      props[:fit] = node.properties[:fit] if node.properties[:fit]
      props[:trim] = node.properties[:trim] if node.properties[:trim]
      props[:align] = node.properties[:align] if node.properties[:align]
      props[:valign] = node.properties[:valign] if node.properties[:valign]
    when "Group"
      props[:x] = node.x if node.respond_to?(:x) && node.x && node.x != 0
      props[:y] = node.y if node.respond_to?(:y) && node.y && node.y != 0
      props[:width] = node.properties[:width] if node.properties[:width]
      props[:height] = node.properties[:height] if node.properties[:height]
    when "Stack"
      props[:direction] = node.properties[:direction] if node.properties[:direction]
      props[:spacing] = node.properties[:spacing] if node.properties[:spacing]
    else
      # Effects and others: dump relevant properties
      node.properties.each do |k, v|
        props[k] = v unless v.nil?
      end
    end

    props
  end

  def collect_nodes(hash, path = "")
    return [] if hash.nil?

    current = "#{path}/#{hash[:type]}(#{hash[:properties].to_s[0..40]})"
    children = (hash[:children] || []).each_with_index.flat_map { |c, i| collect_nodes(c, "#{current}[#{i}]") }
    effects = (hash[:effects] || []).each_with_index.flat_map { |e, i| collect_nodes(e, "#{current}.fx[#{i}]") }

    [current] + children + effects
  end
end
