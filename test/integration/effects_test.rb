require "test_helper"

class EffectsTest < Minitest::Test
  def setup
    @output_dir = "test/tmp/effects"
    FileUtils.mkdir_p(@output_dir)
  end

  def test_displacement
    reference = "test/assets/references/displacement.png"
    
    image = Loomy.generate(size: [200, 200]) do
      layer "test/assets/grid.png" do
        displace map: "test/assets/disp_map.png", scale: 20
      end
    end
    
    assert_image_similar(reference, image)
  end
  
  def test_lighting
    reference = "test/assets/references/lighting.png"

    image = Loomy.generate(size: [200, 200]) do
      layer "test/assets/base.png" do
        relight map: "test/assets/disp_map.png", type: :soft
      end
    end
    
    assert_image_similar(reference, image)
  end

  def test_blur
    reference = "test/assets/references/blur.png"

    image = Loomy.generate(size: [200, 200]) do
      layer "test/assets/base.png" do
        blur radius: 5
      end
    end
    
    assert_image_similar(reference, image)
  end

  def test_grayscale
    reference = "test/assets/references/grayscale.png"

    image = Loomy.generate(size: [200, 200]) do
      layer "test/assets/base.png" do
        grayscale
      end
    end
    
    assert_image_similar(reference, image)
  end
end