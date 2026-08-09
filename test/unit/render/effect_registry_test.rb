# frozen_string_literal: true

require 'test_helper'

class EffectRegistryTest < Minitest::Test
  # An effect nothing has ever registered a processor for.
  class Unregistered < Loomy::AST::Effect; end

  # A caller's own variation on a built-in. The registry keys on the exact class,
  # so this finds no processor of its own.
  class CustomBlur < Loomy::AST::Effects::Blur; end

  def setup
    @image = Vips::Image.black(4, 4)
    @doubled = ->(image, _effect, _loader) { image.linear(2, 0) }
  end

  def test_a_registered_processor_is_applied
    registry = Loomy::Render::EffectRegistry.new({ Unregistered => @doubled }, nil)

    refute_same @image, registry.apply(@image, [Unregistered.new])
  end

  # It used to be skipped, which handed back an image the declaration did not ask
  # for with nothing saying so -- the same silently-wrong output as an unparseable
  # colour rendering black.
  def test_an_effect_with_no_processor_raises
    registry = Loomy::Render::EffectRegistry.new({ Unregistered => @doubled }, nil)

    error = assert_raises(Loomy::UnknownEffect) { registry.apply(@image, [CustomBlur.new(radius: 3)]) }

    assert_equal CustomBlur, error.effect_class
    assert_match(/CustomBlur/, error.message)
  end

  # Inheriting the parent's processor would apply the wrong operation and read the
  # subclass' own parameters as the parent's, so the near-miss has to be loud.
  def test_a_subclass_of_a_registered_effect_does_not_inherit_its_processor
    registry = Loomy::Render::EffectRegistry.snapshot(nil)

    assert_raises(Loomy::UnknownEffect) { registry.apply(@image, [CustomBlur.new(radius: 3)]) }
    refute_same @image, registry.apply(@image, [Loomy::AST::Effects::Blur.new(radius: 3)])
  end

  # It is a fault in the declaration, not in the render: the composition named an
  # effect that does not exist, the same way `use :nope` names a missing style.
  def test_it_is_a_declaration_error
    assert_operator Loomy::UnknownEffect, :<, Loomy::DeclarationError
  end
end
