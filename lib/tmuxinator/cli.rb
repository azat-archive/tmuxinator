module Tmuxinator
  class Cli < Thor
    include Tmuxinator::Util

    COMMANDS = {
      commands: "Lists commands available in tmuxinator",
      completions: "Used for shell completion",
      new: "Create a new project file and open it in your editor",
      open: "Alias of new",
      start: "Start a tmux session using a project's tmuxinator config, with an optional [ALIAS] for project reuse",
      debug: "Output the shell commands that are generated by tmuxinator",
      copy: "Copy an existing project to a new project and open it in your editor",
      delete: "Deletes given project",
      implode: "Deletes all tmuxinator projects",
      version: "Display installed tmuxinator version",
      doctor: "Look for problems in your configuration",
      list: "Lists all tmuxinator projects"
    }

    package_name "tmuxinator" unless Gem::Version.create(Thor::VERSION) < Gem::Version.create("0.18")

    desc "commands", COMMANDS[:commands]

    def commands(shell = nil)
      out = if shell == "zsh"
        COMMANDS.map do |command, desc|
          "#{command}:#{desc}"
        end.join("\n")
      else
        COMMANDS.keys.join("\n")
      end

      puts out
    end

    desc "completions [arg1 arg2]", COMMANDS[:completions]

    def completions(arg)
      if %w(start open copy delete).include?(arg)
        configs = Tmuxinator::Config.configs
        puts configs
      end
    end

    desc "new [PROJECT]", COMMANDS[:new]
    map "open" => :new
    map "edit" => :new
    map "o" => :new
    map "e" => :new
    map "n" => :new

    def new(name)
      config = Tmuxinator::Config.project(name)

      unless Tmuxinator::Config.exists?(name)
        template = Tmuxinator::Config.default? ? Tmuxinator::Config.default : Tmuxinator::Config.sample
        erb  = Erubis::Eruby.new(File.read(template)).result(binding)
        File.open(config, "w") { |f| f.write(erb) }
      end

      Kernel.system("$EDITOR #{config}") || doctor
    end

    no_commands{
      def create_project(name, custom_name, cli_options)
        options={
          :force_attach => false,
          :force_detach => false
        }

        cli_attach=cli_options[:attach]
        if !cli_attach.nil?
          if cli_attach
            options[:force_attach] = true
          else
            options[:force_detach] = true
          end
        end

        options[:custom_name] = custom_name

        project = Tmuxinator::Config.validate(name, options)
        project
      end
    }

    desc "start [PROJECT] [SESSION_NAME]", COMMANDS[:start]
    map "s" => :start
    method_option :attach, :type => :boolean, :aliases => "-a", :desc => "Attach to tmux session after creation."

    def start(name, custom_name  = nil)
      project = create_project(name, custom_name, options)

      if project.deprecations.any?
        project.deprecations.each { |deprecation| say deprecation, :red }
        puts
        print "Press ENTER to continue."
        STDIN.getc
      end

      Kernel.exec(project.render)
    end

    method_option :attach, :type => :boolean, :aliases => "-a", :desc => "Attach to tmux session after creation."
    desc "debug [PROJECT] [SESSION_NAME]", COMMANDS[:debug]

    def debug(name, custom_name  = nil)
      project = create_project(name, custom_name, options)
      puts project.render
    end

    desc "copy [EXISTING] [NEW]", COMMANDS[:copy]
    map "c" => :copy
    map "cp" => :copy

    def copy(existing, new)
      existing_config_path = Tmuxinator::Config.project(existing)
      new_config_path = Tmuxinator::Config.project(new)

      exit!("Project #{existing} doesn't exist!") unless Tmuxinator::Config.exists?(existing)

      if !Tmuxinator::Config.exists?(new) or yes?("#{new} already exists, would you like to overwrite it?", :red)
        say "Overwriting #{new}" if Tmuxinator::Config.exists?(new)
        FileUtils.copy_file(existing_config_path, new_config_path)
      end

      Kernel.system("$EDITOR #{new_config_path}")
    end

    desc "delete [PROJECT]", COMMANDS[:delete]
    map "d" => :delete
    map "rm" => :delete

    def delete(project)
      if Tmuxinator::Config.exists?(project)
        config =  "#{Tmuxinator::Config.root}/#{project}.yml"

        if yes?("Are you sure you want to delete #{project}?(y/n)", :red)
          FileUtils.rm(config)
          say "Deleted #{project}"
        end
      else
        exit!("That file doesn't exist.")
      end
    end

    desc "implode", COMMANDS[:implode]
    map "i" => :implode

    def implode
      if yes?("Are you sure you want to delete all tmuxinator configs?", :red)
        FileUtils.remove_dir(Tmuxinator::Config.root)
        say "Deleted all tmuxinator projects."
      end
    end

    desc "list", COMMANDS[:list]
    map "l" => :list
    map "ls" => :list

    def list
      say "tmuxinator projects:"

      print_in_columns Tmuxinator::Config.configs
    end

    desc "version", COMMANDS[:version]
    map "-v" => :version

    def version
      say "tmuxinator #{Tmuxinator::VERSION}"
    end

    desc "doctor", COMMANDS[:doctor]

    def doctor
      say "Checking if tmux is installed ==> "
      yes_no Tmuxinator::Config.installed?

      say "Checking if $EDITOR is set ==> "
      yes_no Tmuxinator::Config.editor?

      say "Checking if $SHELL is set ==> "
      yes_no  Tmuxinator::Config.shell?
    end
  end
end
