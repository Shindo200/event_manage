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
end
