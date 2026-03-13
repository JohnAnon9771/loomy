require_relative '../lib/loomy'
require 'pp'

puts "\e[36m"
puts "╔══════════════════════════════════════════════╗"
puts "║  Loomy — Demo: Arquitetura de Compiladores   ║"
puts "╚══════════════════════════════════════════════╝"
puts "\e[0m"

# ── Parte 1: Montar a AST manualmente ──────────────────────

puts "\n\e[33m── 1. AST Original (A Comanda Suja) ──\e[0m\n\n"

canvas = Loomy::AST::Canvas.new(size: [800, 600])
grupo = Loomy::AST::Group.new(x: 10, y: 10)

# Camada visível
camada_visivel = Loomy::AST::Layer.new(source: "logo.png", width: 100)

# Camada inútil (width 0)
camada_invisivel = Loomy::AST::Layer.new(source: "error.png", width: 0)

grupo.children << camada_visivel
grupo.children << camada_invisivel
canvas.children << grupo

pp canvas
puts "\n→ Note a camada 'error.png' com width: 0 🔴"

# ── Parte 2: Rodar o Otimizador ────────────────────────────

puts "\n\e[33m── 2. Otimizador em Ação (O Gerente) ──\e[0m\n\n"

optimizer = Loomy::AST::Optimizer.new(canvas)
canvas_otimizado = optimizer.call

puts "Otimizando... ✂️"

# ── Parte 3: AST Limpa ─────────────────────────────────────

puts "\n\e[33m── 3. AST Final (A Comanda Limpa) ──\e[0m\n\n"

pp canvas_otimizado
puts "\n→ A camada 'error.png' foi REMOVIDA antes de chegar no libvips! ✅"

# ── Parte 4: Render real (se tiver imagens de teste) ───────

puts "\n\e[33m── 4. Render Real com DSL ──\e[0m\n\n"

begin
  Loomy.render("demo_output.png", size: [800, 600]) do
    layer "base.jpg"
    layer "art.png", x: 50, y: 50
  end
  puts "→ Imagem 'demo_output.png' gerada com sucesso! 🖼️"
rescue => e
  puts "→ (Render pulado: #{e.message})"
end

puts "\n\e[36m═══ Fim da demo! ═══\e[0m"
