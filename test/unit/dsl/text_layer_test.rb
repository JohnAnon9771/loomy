# frozen_string_literal: true

require 'test_helper'

# A text layer has no box to be scaled into, so a height or a scaling fit would
# size a frame the renderer never draws. Refused at declaration, in both forms,
# rather than laid out wrong.
class TextLayerDeclarationTest < Minitest::Test
  def test_a_text_layer_refuses_a_height
    error = assert_raises(Loomy::InvalidValue) { build { layer text: 'Sale', width: 60, height: 20 } }

    assert_equal :height, error.property
    assert_match(/on text layer.*width: sets where they break/m, error.message)
  end

  def test_a_text_layer_refuses_the_fits_that_would_scale_it
    %i[cover stretch].each do |fit|
      error = assert_raises(Loomy::InvalidValue) do
        build do
          layer do
            text 'Sale'
            fit fit
          end
        end
      end

      assert_equal :fit, error.property
    end
  end

  def test_a_text_layer_accepts_contain_because_it_is_the_default
    build { layer text: 'Sale', width: 60, fit: :contain }
  end

  # Which source a layer draws is the layer's call: `source:` wins over
  # `text:`, so a file layer that also carries text keeps its height.
  def test_the_text_rules_apply_only_to_a_layer_that_draws_text
    build { layer 'test/assets/base.png', text: 'unused', height: 20, fit: :cover }
  end

  private

  def build(**, &)
    Loomy::DSL::PipelineBuilder.new(Loomy::Render::SourceCache.new, { size: [100, 100], ** }, &).build
  end
end
