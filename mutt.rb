require 'formula'

class Mutt < Formula
  desc "Mongrel of mail user agents (part elm, pine, mush, mh, etc.)"
  homepage "http://www.mutt.org/"
  #url "https://bitbucket.org/mutt/mutt/downloads/mutt-1.5.24.tar.gz"
  #mirror "ftp://ftp.mutt.org/pub/mutt/mutt-1.5.24.tar.gz"
  #sha256 "a292ca765ed7b19db4ac495938a3ef808a16193b7d623d65562bb8feb2b42200"
  url 'ftp://ftp.mutt.org/pub/mutt/mutt-1.5.23.tar.gz'
  sha256 '3af0701e57b9e1880ed3a0dee34498a228939e854a16cdccd24e5e502626fd37'
  revision 2

  head do
    url "http://dev.mutt.org/hg/mutt#default", :using => :hg

    resource "html" do
      #url "http://dev.mutt.org/doc/manual.html", :using => :nounzip
      url "https://muttmua.gitlab.io/mutt/manual-dev.html"
    end
  end

  # trying to rename
  #conflicts_with 'tin',
  #  :because => 'both install mmdf.5 and mbox.5 man pages'

  option "with-debug", "Build with debug option enabled"
  option "with-s-lang", "Build against slang instead of ncurses"
  option "with-ignore-thread-patch", "Apply ignore-thread patch"
  option "with-confirm-attachment-patch", "Apply confirm attachment patch"
  option "with-trash-patch", "Apply trash folder patch"
  option "with-pgp-verbose-mime-patch", "Apply PGP verbose mime patch"
  option "with-sidebar-patch", "Apply sidebar (folder list) patch" unless build.head?
  option "with-gmail-server-search-patch", "Apply gmail server search patch"
  option "with-gmail-labels-patch", "Apply gmail labels patch"

  depends_on "autoconf" => :build
  depends_on "automake" => :build

  depends_on "openssl"
  depends_on "tokyo-cabinet"
  depends_on "gettext" => :optional
  depends_on "gpgme" => :optional
  depends_on "libidn" => :optional
  depends_on "s-lang" => :optional
  if build.head?
    depends_on :autoconf
    depends_on :automake
  end

  patch do
    #url "ftp://ftp.openbsd.org/pub/OpenBSD/distfiles/mutt/trashfolder-1.5.22.diff0.gz"
    # My patch applies both Trash and Purge patches
    url 'https://raw.github.com/kuperman/Mutt-Trash-Purge-patch/master/patch-1.5.23.bk.trash_folder-purge_message.1'
    sha256 '6127d21f701b2a5d63aa910ae48e232504ec456e346dd2c370b6c5c244cc2b9e'
  end if build.with? "trash-patch"

  # original source for this went missing, patch sourced from Arch at
  # https://aur.archlinux.org/packages/mutt-ignore-thread/
  if build.with? "ignore-thread-patch"
    patch do
      url "https://gist.githubusercontent.com/mistydemeo/5522742/raw/1439cc157ab673dc8061784829eea267cd736624/ignore-thread-1.5.21.patch"
      sha256 "7290e2a5ac12cbf89d615efa38c1ada3b454cb642ecaf520c26e47e7a1c926be"
    end
  end

  if build.with? "confirm-attachment-patch"
    patch do
      url "https://gist.githubusercontent.com/tlvince/5741641/raw/c926ca307dc97727c2bd88a84dcb0d7ac3bb4bf5/mutt-attach.patch"
      sha256 "da2c9e54a5426019b84837faef18cc51e174108f07dc7ec15968ca732880cb14"
    end
  end

  patch do
    url "https://raw.githubusercontent.com/kuperman/homebrew-mutt/master/patches/patch-1.5.4.vk.pgp_verbose_mime"
    sha256 'fbd58cd5466c71e39a3854dc6b91e05ac7ea410eec49148a0eb6ef8aa584789b'
  end if build.with? "pgp-verbose-mime-patch"

  patch do
    url "https://github.com/kuperman/homebrew-mutt/raw/c68c72bf2824b571b56c63aee597a43fb12b7705/patches/mutt-sidebar.patch"
    sha256 'de592f9eeae458cac8de15a22230b3b426da71a62369617030a84787ccb08712'
  end if build.with? "sidebar-patch"

  patch :p0 do
    url "https://github.com/kuperman/homebrew-mutt/raw/c68c72bf2824b571b56c63aee597a43fb12b7705/patches/patch-mutt-gmailcustomsearch.v1.patch"
    sha256 'de0ed37985b254ed365539808ec99be4ff904dbf32e4ab4baae0309bfa38ca77'
  end if build.with? "gmail-server-search-patch"

  patch do
    url "https://github.com/kuperman/homebrew-mutt/raw/231547c95422db3aa834383fd01f1464f99db228/patches/mutt-1.5.23-gmail-labels.sgeb.v1.patch"
    sha256 '2b80584e0e799d798f250f6559d6f9bb517ac4a7c47e739318eb8263c8f67a7c'
  end if build.with? "gmail-labels-patch"

  def install
    user_admin = Etc.getgrnam("admin").mem.include?(ENV["USER"])
    #user_admin = Etc.getgrnam("mail").mem.include?(ENV["USER"])

    args = %W[
      --disable-dependency-tracking
      --disable-warnings
      --prefix=#{prefix}
      --with-ssl=#{Formula["openssl"].opt_prefix}
      --with-sasl
      --with-gss
      --enable-imap
      --enable-smtp
      --enable-pop
      --enable-hcache
      --with-tokyocabinet
    ]

    # This is just a trick to keep 'make install' from trying
    # to chgrp the mutt_dotlock file (which we can't do if
    # we're running as an unprivileged user)
    args << "--with-homespool=.mbox" unless user_admin

    args << "--disable-nls" if build.without? "gettext"
    args << "--enable-gpgme" if build.with? "gpgme"
    args << "--with-slang" if build.with? "s-lang"

    if build.with? "debug"
      args << "--enable-debug"
    else
      args << "--disable-debug"
    end

    # Fix filename conflicts
    inreplace ["doc/Makefile.in", "doc/Makefile.am"] do |s|
        s.gsub! "mmdf.5", "mmdf-mutt.5"
        s.gsub! "mbox.5", "mbox-mutt.5"
    end

    # This permits the `mutt_dotlock` file to be installed under a group
    # that isn't `mail`.
    # https://github.com/Homebrew/homebrew/issues/45400
    if user_admin
      inreplace "configure.ac", /DOTLOCK_GROUP='mail'/, "DOTLOCK_GROUP='admin'"
      # the distribution didn't clean up from configure, need to "prepare" below
      rm "aclocal.m4"
      #inreplace "configure", /DOTLOCK_GROUP='mail'/, "DOTLOCK_GROUP='admin'"
    end

    if build.head? || user_admin
      system "./prepare", *args
    else
      system "./configure", *args
    end
    system "make"

    system "make", "install"
    doc.install resource("html") if build.head?
  end

  test do
    system bin/"mutt", "-D"
  end
end
