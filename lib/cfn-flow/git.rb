# Git helper module
class CfnFlow::Git
  class << self

    def sha
      command = "git rev-parse --verify HEAD"
      result = `#{command}`.chomp
      unless $?.success?
        raise Thor::Error.new("Error running `#{command}`")
      end
      result
    end

    def check_status
      unless `git status -s`.empty?
        raise Thor::Error.new("Git working directory is not clean. Please commit or reset changes in order to release.")
      end
      unless $?.success?
        raise Thor::Error.new("Error running `git status`")
      end
    end

  end
end
