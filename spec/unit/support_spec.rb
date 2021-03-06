# frozen_string_literal: true

RSpec.describe TTY::Color::Support, "#support?" do
  it "doesn't check color support for non tty terminal" do
    support = described_class.new({})
    allow(TTY::Color).to receive(:tty?).and_return(false)
    expect(support.support?).to eq(false)
  end

  it "disables color support when NO_COLOR is set" do
    support = described_class.new({"NO_COLOR" => "1"})
    expect(support.support?).to eq(false)
    expect(support).to be_disabled
  end

  it "fails to find out color support" do
    support = described_class.new({})
    allow(TTY::Color).to receive(:tty?).and_return(true)

    allow(support).to receive(:from_curses).and_return(TTY::Color::NoValue)
    allow(support).to receive(:from_tput).and_return(TTY::Color::NoValue)
    allow(support).to receive(:from_term).and_return(TTY::Color::NoValue)
    allow(support).to receive(:from_env).and_return(TTY::Color::NoValue)

    expect(support.support?).to eq(false)

    expect(support).to have_received(:from_term).ordered
    expect(support).to have_received(:from_tput).ordered
    expect(support).to have_received(:from_env).ordered
    expect(support).to have_received(:from_curses).ordered
  end

  it "detects color support" do
    support = described_class.new({"TERM" => "xterm"})
    allow(TTY::Color).to receive(:tty?).and_return(true)
    allow(support).to receive(:from_tput)

    expect(support.support?).to eq(true)
    expect(support).to_not have_received(:from_tput)
  end

  context "#from_curses" do
    it "fails to load curses for color support" do
      support = described_class.new({})
      allow(TTY::Color).to receive(:windows?).and_return(false)
      allow(support).to receive(:require).with("curses").and_raise(LoadError)
      allow(support).to receive(:warn)

      expect(support.from_curses).to eq(TTY::Color::NoValue)
      expect(support).to_not have_received(:warn)
    end

    it "fails to find Curses namespace" do
      support = described_class.new({})
      allow(TTY::Color).to receive(:windows?).and_return(false)
      allow(support).to receive(:require).with("curses")

      expect(support.from_curses).to eq(TTY::Color::NoValue)
    end

    it "sets verbose mode on" do
      support = described_class.new({}, verbose: true)
      allow(TTY::Color).to receive(:windows?).and_return(false)
      allow(support).to receive(:require).with("curses").and_raise(LoadError)
      allow(support).to receive(:warn)

      support.from_curses

      expect(support).to have_received(:warn).with(/no native curses support/)
    end

    it "loads curses for color support" do
      support = described_class.new({})
      allow(TTY::Color).to receive(:windows?).and_return(false)
      allow(support).to receive(:require).with("curses").and_return(true)
      stub_const("Curses", Object.new)
      curses = double(:curses)
      allow(curses).to receive(:init_screen)
      allow(curses).to receive(:has_colors?).and_return(true)
      allow(curses).to receive(:close_screen)

      expect(support.from_curses(curses)).to eql(true)
      expect(curses).to have_received(:has_colors?)
    end

    it "doesn't check on windows" do
      support = described_class.new({})
      allow(TTY::Color).to receive(:windows?).and_return(true)
      expect(support.from_curses).to eq(TTY::Color::NoValue)
    end
  end

  context "#from_term" do
    it "fails to find color for dumb terminal" do
      support = described_class.new({"TERM" => "dumb"})
      expect(support.from_term).to eq(false)
    end

    it "inspects term variable for color capabilities" do
      support = described_class.new({"TERM" => "xterm"})
      expect(support.from_term).to eq(true)
      support = described_class.new({"TERM" => "tmux-256color"})
      expect(support.from_term).to eq(true)
    end

    it "fails to find color capabilities from term variable " do
      support = described_class.new({"TERM" => "atari"})
      expect(support.from_term).to eq(TTY::Color::NoValue)
    end
  end

  context "#from_tput" do
    it "fails to find tput utilty" do
      support = described_class.new({})
      allow(TTY::Color).to receive(:command?).with("tput colors").and_return(nil)

      expect(support.from_tput).to eq(TTY::Color::NoValue)
    end

    it "runs tput and detects 8 colors" do
      allow(TTY::Color).to receive(:command?).with("tput colors").and_return(true)
      support = described_class.new({})
      allow(support).to receive(:`).and_return("8")

      expect(support.from_tput).to eq(true)
    end

    it "runs tput but finds no colors" do
      allow(TTY::Color).to receive(:command?).with("tput colors").and_return(true)
      support = described_class.new({})
      allow(support).to receive(:`).and_return("2")

      expect(support.from_tput).to eq(false)
    end

    it "raises error when running tput" do
      allow(TTY::Color).to receive(:command?).with("tput colors").and_return(true)
      support = described_class.new({})
      allow(support).to receive(:`).and_raise(Errno::ENOENT)

      expect(support.from_tput).to eq(TTY::Color::NoValue)
    end
  end

  context "#from_env" do
    it "finds color support in colorterm variable" do
      support = described_class.new({"COLORTERM" => true})
      expect(support.from_env).to eq(true)
    end

    it "finds ansicon support" do
      support = described_class.new({"ANSICON" => true})
      expect(support.from_env).to eq(true)
    end

    it "doesn't find any keys in environment" do
      support = described_class.new({})
      expect(support.from_env).to eq(TTY::Color::NoValue)
    end
  end
end
