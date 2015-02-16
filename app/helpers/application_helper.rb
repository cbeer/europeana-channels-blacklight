module ApplicationHelper
  def render_document_preview options
    image_tag options[:value]
  end
end
