require "sinatra"
require "json"
require_relative "../lib/loomy"
require_relative "lib/ast_serializer"

set :port, 4567
set :bind, "0.0.0.0"
set :public_folder, File.join(__dir__, "public")

get "/" do
  send_file File.join(settings.public_folder, "index.html")
end

post "/api/parse" do
  content_type :json

  body = JSON.parse(request.body.read)
  code = body["code"].to_s
  width = (body["width"] || 800).to_i
  height = (body["height"] || 600).to_i

  begin
    # Build AST from DSL code
    block = eval("Proc.new { #{code} }")
    canvas_pre = Loomy::DSL::PipelineBuilder.new({ size: [width, height] }, &block).build

    # Deep clone before optimization (optimizer mutates in-place)
    pre_hash = AstSerializer.serialize(canvas_pre)
    canvas_post = AstSerializer.deep_clone(canvas_pre)

    # Optimize
    Loomy::AST::Optimizer.new(canvas_post).call
    post_hash = AstSerializer.serialize(canvas_post)

    { pre: pre_hash, post: post_hash }.to_json
  rescue SyntaxError => e
    status 422
    { error: "Erro de sintaxe: #{e.message.lines.first.strip}" }.to_json
  rescue => e
    status 422
    { error: "#{e.class}: #{e.message}" }.to_json
  end
end
