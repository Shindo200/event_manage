class NilClass
  def blank?
    true
  end
end

class String
  def blank?
    return false if self.size > 0
    true
  end

  def truncate(opts = {})
    opts[:omission] ||= "..."
    opts[:limit] ||= 30
    text = self
    if text.size > opts[:limit]
      max_size = opts[:limit] - opts[:omission].size
      text = text[0..max_size] + opts[:omission]
    end
    text
  end
end
