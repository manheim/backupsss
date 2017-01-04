require 'spec_helper'
require 'backupsss/tar'

def dbl_exitstatus(code)
  d = double
  allow(d).to receive(:exitstatus).and_return(code)
  d
end

describe Backupsss::Tar do
  let(:empty_src) { 'spec/fixtures/backup_src/empty' }
  let(:valid_src) { 'spec/fixtures/backup_src/with_data' }
  let(:src)       { 'spec/fixtures/backup_src' }
  let(:filename)  { 'backup.tar' }
  let(:dest)      { "spec/fixtures/backups_dest/#{filename}" }
  before          { allow(File).to receive(:exist?) { true } }

  describe '#filename' do
    subject { Backupsss::Tar.new(valid_src, dest).filename }

    it { is_expected.to eq(filename) }
  end

  describe '#valid_src?' do
    context 'when src does not exist on the file system' do
      subject { -> { Backupsss::Tar.new('does_not_exist', '').valid_src? } }

      it { is_expected.to raise_error(Errno::ENOENT) }
      it { is_expected.to raise_error(/does_not_exist$/) }
    end

    context 'when src is not readable' do
      subject { -> { Backupsss::Tar.new(empty_src, '').valid_src? } }
      before  { allow(File).to receive(:readable?) { false } }

      it { is_expected.to raise_error(Errno::EPERM) }
      it { is_expected.to raise_error(/#{empty_src}$/) }
    end

    context 'when src exists and is readable' do
      subject { Backupsss::Tar.new(valid_src, '').valid_src? }

      it { is_expected.to be true }
    end
  end

  describe '#valid_dest?' do
    context 'when dest dir does not exist on the file system' do
      let(:invalid_dest) { "spec/fixtures/invalid/#{filename}" }
      subject { -> { Backupsss::Tar.new(valid_src, invalid_dest).valid_dest? } }

      it { is_expected.to raise_error(Errno::ENOENT) }
      it { is_expected.to raise_error(%r{spec\/fixtures\/invalid$}) }
    end

    context 'when dest dir is not writable' do
      subject { -> { Backupsss::Tar.new(valid_src, dest).valid_dest? } }
      before { allow(File).to receive(:writable?) { false } }

      it { is_expected.to raise_error(Errno::EPERM) }
      it { is_expected.to raise_error(/#{File.dirname(dest)}$/) }
    end

    context 'when dest dir exists and is writable' do
      before  { allow(File).to receive(:writable?) { true } }
      subject { Backupsss::Tar.new('', dest).valid_dest? }

      it { is_expected.to be true }
    end
  end

  describe '#tar_command' do
    context 'compress_archive true' do
      subject { Backupsss::Tar.new('src/', 'dest.tar').tar_command }

      it { is_expected.to eq('tar -zcvf') }
    end

    context 'compress_archive false' do
      subject { Backupsss::Tar.new('src/', 'dest.tar', false).tar_command }

      it { is_expected.to eq('tar -cvf') }
    end
  end

  describe '#make' do
    context 'when src and dest dir exist with correct permissions' do
      subject { Backupsss::Tar.new(valid_src, dest) }

      it 'returns a File object' do
        expect(subject.make).to be_kind_of(File)
      end

      it 'exits cleanly' do
        expect { subject.make }.to_not output.to_stderr
      end
    end
  end

  describe '#check_tar_result' do
    context 'when tar exits non-zero' do
      let(:subject) { Backupsss::Tar.new(src, dest) }
      let(:dbl_status) { dbl_exitstatus(3) }
      it 'raises an error' do
        allow(subject).to receive(:tar_command).and_return('tarcmd')
        allow(File).to receive(:exist?).and_return(true)
        allow(File).to receive(:size).and_return(999)

        expect { subject.check_tar_result(dbl_status) }
          .to raise_error(RuntimeError, /ERROR: tarcmd exited 3/)
      end
    end
    context 'when destination file does not exist' do
      let(:subject) { Backupsss::Tar.new(src, dest) }
      let(:dbl_status) { dbl_exitstatus(0) }
      it 'raises an error' do
        allow(subject).to receive(:tar_command).and_return('tarcmd')
        allow(File).to receive(:exist?).and_return(false)
        allow(File).to receive(:size).and_return(999)

        expect(File).to receive(:exist?).once.with(dest)
        expect(File).to_not receive(:size)
        expect { subject.check_tar_result(dbl_status) }.to raise_error(
          RuntimeError, /ERROR: Tar destination file does not exist/
        )
      end
    end
    context 'when destination file is 0 bytes' do
      let(:subject) { Backupsss::Tar.new(src, dest) }
      let(:dbl_status) { dbl_exitstatus(0) }
      it 'raises an error' do
        allow(subject).to receive(:tar_command).and_return('tarcmd')
        allow(File).to receive(:exist?).and_return(true)
        allow(File).to receive(:size).and_return(0)

        expect(File).to receive(:exist?).once.ordered.with(dest)
        expect(File).to receive(:size).once.ordered.with(dest)
        expect { subject.check_tar_result(dbl_status) }.to raise_error(
          RuntimeError, /ERROR: Tar destionation file is 0 bytes\./
        )
      end
    end
  end
end
