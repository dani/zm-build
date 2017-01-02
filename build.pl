#!/usr/bin/perl

use strict;

use File::Basename;
use Data::Dumper;
use Cwd;

my $GLOBAL_PATH_TO_SCRIPT;
my $GLOBAL_PATH_TO_SCRIPT_DIR;
my $GLOBAL_PATH_TO_TOP;
my $GLOBAL_PATH_TO_BUILDS;

my $GLOBAL_BUILD_NO;
my $GLOBAL_BUILD_TS;
my $GLOBAL_BUILD_DIR;
my $GLOBAL_BUILD_OS;
my $GLOBAL_BUILD_RELEASE;
my $GLOBAL_BUILD_RELEASE_NO;
my $GLOBAL_BUILD_RELEASE_NO_SHORT;
my $GLOBAL_BUILD_RELEASE_CANDIDATE;
my $GLOBAL_BUILD_TYPE;
my $GLOBAL_BUILD_ARCH;
my $GLOBAL_THIRDPARTY_SERVER;


BEGIN
{
   $GLOBAL_PATH_TO_SCRIPT     = Cwd::abs_path(__FILE__);
   $GLOBAL_PATH_TO_SCRIPT_DIR = dirname($GLOBAL_PATH_TO_SCRIPT);
   $GLOBAL_PATH_TO_TOP        = dirname($GLOBAL_PATH_TO_SCRIPT_DIR);
}

chdir($GLOBAL_PATH_TO_TOP);

##############################################################################################

main();

##############################################################################################

sub main()
{
   InitGlobalBuildVars();
   Prepare();
   Checkout("public_repos.pl");
   Checkout("private_repos.pl") if ( $GLOBAL_BUILD_TYPE eq "NETWORK" );
   Build();
}

sub InitGlobalBuildVars()
{
   if ( -f "/tmp/last.build_no_ts" && $ENV{ENV_RESUME_FLAG} )
   {
      my $x = LoadProperties("/tmp/last.build_no_ts");

      $GLOBAL_BUILD_NO = $x->{BUILD_NO};
      $GLOBAL_BUILD_TS = $x->{BUILD_TS};
   }

   $GLOBAL_BUILD_NO ||= GetNewBuildNo();
   $GLOBAL_BUILD_TS ||= GetNewBuildTs();

   my $build_cfg = LoadProperties("$GLOBAL_PATH_TO_SCRIPT_DIR/build.config");

   $GLOBAL_PATH_TO_BUILDS          = $build_cfg->{PATH_TO_BUILDS}          || "$GLOBAL_PATH_TO_TOP/BUILDS";
   $GLOBAL_BUILD_RELEASE           = $build_cfg->{BUILD_RELEASE}           || die "not specified BUILD_RELEASE";
   $GLOBAL_BUILD_RELEASE_NO        = $build_cfg->{BUILD_RELEASE_NO}        || die "not specified BUILD_RELEASE_NO";
   $GLOBAL_BUILD_RELEASE_CANDIDATE = $build_cfg->{BUILD_RELEASE_CANDIDATE} || die "not specified BUILD_RELEASE_CANDIDATE";
   $GLOBAL_BUILD_TYPE              = $build_cfg->{BUILD_TYPE}              || die "not specified BUILD_TYPE";
   $GLOBAL_THIRDPARTY_SERVER       = $build_cfg->{THIRDPARTY_SERVER}       || die "not specified THIRDPARTY_SERVER";
   $GLOBAL_BUILD_OS                = GetBuildOS();
   $GLOBAL_BUILD_ARCH              = GetBuildArch();

   s/[.]//g for ( $GLOBAL_BUILD_RELEASE_NO_SHORT = $GLOBAL_BUILD_RELEASE_NO );

   $GLOBAL_BUILD_DIR = "$GLOBAL_PATH_TO_BUILDS/$GLOBAL_BUILD_OS/$GLOBAL_BUILD_RELEASE-$GLOBAL_BUILD_RELEASE_NO_SHORT/${GLOBAL_BUILD_TS}_$GLOBAL_BUILD_TYPE";

   print "=========================================================================================================\n";
   print "BUILD OS                : $GLOBAL_BUILD_OS\n";
   print "BUILD ARCH              : $GLOBAL_BUILD_ARCH\n";
   print "BUILD NO                : $GLOBAL_BUILD_NO\n";
   print "BUILD TS                : $GLOBAL_BUILD_TS\n";
   print "BUILD TYPE              : $GLOBAL_BUILD_TYPE\n";
   print "BUILD RELEASE           : $GLOBAL_BUILD_RELEASE\n";
   print "BUILD RELEASE NO        : $GLOBAL_BUILD_RELEASE_NO\n";
   print "BUILD RELEASE CANDIDATE : $GLOBAL_BUILD_RELEASE_CANDIDATE\n";
   print "=========================================================================================================\n";

   $ENV{ENV_GIT_UPDATE_EXCLUDE} = '.*' if ( $ENV{ENV_GIT_UPDATE_INCLUDE} );
   $ENV{ENV_PACKAGE_EXCLUDE}    = '.*' if ( $ENV{ENV_PACKAGE_INCLUDE} );
   $ENV{ENV_BUILD_EXCLUDE}      = '.*' if ( $ENV{ENV_BUILD_INCLUDE} );

   foreach my $x (`grep -o '\\<[E][N][V]_[A-Z_]*\\>' $GLOBAL_PATH_TO_SCRIPT | sort | uniq`)
   {
      chomp($x);
      printf( "%-24s: $ENV{$x}\n", $x );
   }

   print "=========================================================================================================\n";
   print "PATH TO BUILDS          : $GLOBAL_PATH_TO_BUILDS\n";
   print "BUILD DIR               : $GLOBAL_BUILD_DIR\n";
   print "=========================================================================================================\n";
   print "Press enter to proceed";
   my $x;
   read STDIN, $x, 1;
}

sub Prepare()
{
   #system("rm", "-rf", "$ENV{HOME}/.zcs-deps");
   #system("rm", "-rf", "$ENV{HOME}/.ivy2/cache");

   open( FD, ">", "/tmp/last.build_no_ts" );
   print FD "BUILD_NO=$GLOBAL_BUILD_NO\n";
   print FD "BUILD_TS=$GLOBAL_BUILD_TS\n";
   close(FD);

   System( "mkdir", "-p", "$GLOBAL_BUILD_DIR" );
   System( "mkdir", "-p", "$GLOBAL_BUILD_DIR/logs" );
   System( "mkdir", "-p", "$ENV{HOME}/.zcs-deps" );
   System( "mkdir", "-p", "$ENV{HOME}/.ivy2/cache" );


   my @TP_JARS = (
      "http://$GLOBAL_THIRDPARTY_SERVER/ZimbraThirdParty/third-party-jars/ant-1.7.0-ziputil-patched.jar",
      "http://$GLOBAL_THIRDPARTY_SERVER/ZimbraThirdParty/third-party-jars/ant-contrib-1.0b1.jar",
      "http://$GLOBAL_THIRDPARTY_SERVER/ZimbraThirdParty/third-party-jars/ews_2010-1.0.jar",
      "http://$GLOBAL_THIRDPARTY_SERVER/ZimbraThirdParty/third-party-jars/jruby-complete-1.6.3.jar",
      "http://$GLOBAL_THIRDPARTY_SERVER/ZimbraThirdParty/third-party-jars/plugin.jar",
      "http://$GLOBAL_THIRDPARTY_SERVER/ZimbraThirdParty/third-party-jars/servlet-api-3.1.jar",
      "http://$GLOBAL_THIRDPARTY_SERVER/ZimbraThirdParty/third-party-jars/unboundid-ldapsdk-2.3.5-se.jar",
      "http://$GLOBAL_THIRDPARTY_SERVER/ZimbraThirdParty/third-party-jars/zimbrastore-test-1.0.jar",
   );

   for my $j_url (@TP_JARS)
   {
      if ( my $f = "$ENV{HOME}/.zcs-deps/" . basename($j_url) )
      {
         if ( !-f $f )
         {
            System("wget '$j_url' -O '$f.tmp'");
            System("mv '$f.tmp' '$f'");
         }
      }
   }
}

sub Checkout($)
{
   my $repo_file = shift;

   if ( !-d "zimbra-package-stub" )
   {
      System( "git", "clone", "https://github.com/Zimbra/zimbra-package-stub.git" );
   }

   if ( !-d "junixsocket" )
   {
      System( "git", "clone", "-b", "junixsocket-parent-2.0.4", "https://github.com/kohlschutter/junixsocket.git" );
   }

   if ( -f "$GLOBAL_PATH_TO_TOP/zm-build/$repo_file" )
   {
      my @REPOS = ();
      eval `cat $GLOBAL_PATH_TO_TOP/zm-build/$repo_file`;
      die "FAILURE in $repo_file, (info=$!, err=$@)\n" if ($@);
      for my $repo_details (@REPOS)
      {
         Clone($repo_details);
      }
   }
}

sub Build()
{
   my @GLOBAL_BUILDS;
   eval `cat $GLOBAL_PATH_TO_TOP/zm-build/global_builds.pl`;
   die "FAILURE in global_builds.pl, (info=$!, err=$@)\n" if ($@);

   for my $build_info (@GLOBAL_BUILDS)
   {
      if ( my $dir = $build_info->{dir} )
      {
         next
           if (
            !( $ENV{ENV_BUILD_INCLUDE} && grep { $build_info->{dir} =~ /$_/ } split( ",", $ENV{ENV_BUILD_INCLUDE} ) )
            && ( $ENV{ENV_BUILD_EXCLUDE} && grep { $build_info->{dir} =~ /$_/ } split( ",", $ENV{ENV_BUILD_EXCLUDE} ) )
           );

         print "=========================================================================================================\n";
         print "BUILDING: $build_info->{dir}\n";
         print "\n";

         if ( -f "$dir/.built.$GLOBAL_BUILD_TS" && $ENV{ENV_RESUME_FLAG} )
         {
            print "WARNING: SKIPPING - delete $dir/.built.$GLOBAL_BUILD_TS to build this\n";
            print "=========================================================================================================\n";
            print "\n";
         }
         else
         {
            Run(
               cd   => $dir,
               call => sub {

                  my $abs_dir = Cwd::abs_path();

                  if ( my $ant_targets = $build_info->{ant_targets} )
                  {
                     my $ANT = $ENV{ENV_ANT_OVERRIDE_CMD} || "ant";

                     System( $ANT, "clean" )
                       if ( $ENV{ENV_ANT_DO_CLEAN_FLAG} || $build_info->{clean_flag} );

                     System( $ANT, @$ant_targets );
                  }

                  if ( my $stage_cmd = $build_info->{stage_cmd} )
                  {
                     &$stage_cmd
                  }
               },
            );

            unlink glob "$dir/.built.*";
            print "Creating $dir/.built.$GLOBAL_BUILD_TS\n";
            open( FD, "> $dir/.built.$GLOBAL_BUILD_TS" );
            close(FD);

            print "\n";
            print "=========================================================================================================\n";
            print "\n";
         }
      }
   }

   Run(
      cd   => "zm-build",
      call => sub {
         System("(cd .. && rsync -az --delete zm-build $GLOBAL_BUILD_DIR/)");
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-build/$GLOBAL_BUILD_ARCH");

         my @ALL_PACKAGES = ();

         push( @ALL_PACKAGES, @{ GetPackageList("public_packages.pl") } );
         push( @ALL_PACKAGES, @{ GetPackageList("private_packages.pl") } ) if ( $GLOBAL_BUILD_TYPE eq "NETWORK" );

         for my $package_script (@ALL_PACKAGES)
         {
            next
              if (
               !( $ENV{ENV_PACKAGE_INCLUDE} && grep { $package_script =~ /$_/ } split( ",", $ENV{ENV_PACKAGE_INCLUDE} ) )
               && ( $ENV{ENV_PACKAGE_EXCLUDE} && grep { $package_script =~ /$_/ } split( ",", $ENV{ENV_PACKAGE_EXCLUDE} ) )
              );

            System(
               "  release='$GLOBAL_BUILD_RELEASE_NO.$GLOBAL_BUILD_RELEASE_CANDIDATE' \\
                  branch='$GLOBAL_BUILD_RELEASE-$GLOBAL_BUILD_RELEASE_NO_SHORT' \\
                  buildNo='$GLOBAL_BUILD_NO' \\
                  os='$GLOBAL_BUILD_OS' \\
                  buildType='$GLOBAL_BUILD_TYPE' \\
                  repoDir='$GLOBAL_BUILD_DIR' \\
                  arch='$GLOBAL_BUILD_ARCH' \\
                  buildTimeStamp='$GLOBAL_BUILD_TS' \\
                  buildLogFile='$GLOBAL_BUILD_DIR/logs/build.log' \\
                  zimbraThirdPartyServer='$GLOBAL_THIRDPARTY_SERVER' \\
                     bash $GLOBAL_PATH_TO_TOP/zm-build/scripts/packages/$package_script.sh
               "
            );
         }
         System(
            "  release='$GLOBAL_BUILD_RELEASE_NO.$GLOBAL_BUILD_RELEASE_CANDIDATE' \\
                branch='$GLOBAL_BUILD_RELEASE-$GLOBAL_BUILD_RELEASE_NO_SHORT' \\
                buildNo='$GLOBAL_BUILD_NO' \\
                os='$GLOBAL_BUILD_OS' \\
                buildType='$GLOBAL_BUILD_TYPE' \\
                repoDir='$GLOBAL_BUILD_DIR' \\
                arch='$GLOBAL_BUILD_ARCH' \\
                buildTimeStamp='$GLOBAL_BUILD_TS' \\
                buildLogFile='$GLOBAL_BUILD_DIR/logs/build.log' \\
                zimbraThirdPartyServer='$GLOBAL_THIRDPARTY_SERVER' \\
                  bash $GLOBAL_PATH_TO_TOP/zm-build/scripts/packages/zcs-bundle.sh
            "
         );
      },
   );

   print "\n";
   print "=========================================================================================================\n";
   print "\n";
}


sub GetPackageList($)
{
   my $package_list_file = shift;

   my @PACKAGES = ();

   if ( -f "$GLOBAL_PATH_TO_TOP/zm-build/$package_list_file" )
   {
      eval `cat $GLOBAL_PATH_TO_TOP/zm-build/$package_list_file`;
      die "FAILURE in $package_list_file, (info=$!, err=$@)\n" if ($@);
   }

   return \@PACKAGES;
}


sub GetNewBuildNo()
{
   my $line = 1000;

   if ( -f "/tmp/build_counter.txt" )
   {
      open( FD1, "<", "/tmp/build_counter.txt" );
      $line = <FD1>;
      close(FD1);

      $line += 2;
   }

   open( FD2, ">", "/tmp/build_counter.txt" );
   printf( FD2 "%s\n", $line );
   close(FD2);

   return $line;
}

sub GetNewBuildTs()
{
   chomp( my $x = `date +'%Y%m%d%H%M%S'` );

   return $x;
}

sub GetBuildOS()
{
   chomp( my $r = `$GLOBAL_PATH_TO_TOP/zm-build/rpmconf/Build/get_plat_tag.sh` );

   return $r
     if ($r);

   die "Unknown OS";
}

sub GetBuildArch()    # FIXME - use standard mechanism
{
   chomp( my $PROCESSOR_ARCH = `uname -m | grep -o 64` );

   my $b_os = GetBuildOS();

   return "amd" . $PROCESSOR_ARCH
     if ( $b_os =~ /UBUNTU/ );

   return "x86_" . $PROCESSOR_ARCH
     if ( $b_os =~ /RHEL/ || $b_os =~ /CENTOS/ );

   die "Unknown Arch"
}


##############################################################################################

sub Clone($)
{
   my $repo_details = shift;

   my $repo_name   = $repo_details->{name};
   my $repo_user   = $repo_details->{user};
   my $repo_branch = $repo_details->{branch};

   if ( !-d $repo_name )
   {
      System( "git", "clone", "-b", $repo_branch, "ssh://git\@stash.corp.synacor.com:7999/$repo_user/$repo_name.git" );
   }
   else
   {
      return
        if (
         !( $ENV{ENV_GIT_UPDATE_INCLUDE} && grep { $repo_name =~ /$_/ } split( ",", $ENV{ENV_GIT_UPDATE_INCLUDE} ) )
         && ( $ENV{ENV_GIT_UPDATE_EXCLUDE} && grep { $repo_name =~ /$_/ } split( ",", $ENV{ENV_GIT_UPDATE_EXCLUDE} ) )
        );

      print "#: Updating $repo_name...\n";

      chomp( my $z = `cd $repo_name && git pull origin` );

      print $z . "\n";

      if ( $z !~ /Already up-to-date/ )
      {
         System( "find", $repo_name, "-name", ".built.*", "-exec", "rm", "-f", "{}", ";" );
      }
   }
}

sub System(@)
{
   print "#: @_            #(pwd=" . Cwd::getcwd() . ")\n";

   my $x = system @_;

   die "FAILURE in system, (info=$!, cmd='@_', ret=$x)\n"
     if ( $x != 0 );
}


sub LoadProperties($)
{
   my $f = shift;

   my $x = SlurpFile($f);

   my %h = map { split( /\s*=\s*/, $_, 2 ) } @$x;

   return \%h;
}


sub SlurpFile($)
{
   my $f = shift;

   open( FD, "<", "$f" ) || die "FAILURE in open, (info=$!, file='$f')\n";

   chomp( my @x = <FD> );
   close(FD);

   return \@x;
}


sub Run(%)
{
   my %args  = (@_);
   my $chdir = $args{cd};
   my $call  = $args{call};

   my $child_pid = fork();

   die "FAILURE while forking, (info=$!)\n"
     if ( !defined $child_pid );

   if ( $child_pid != 0 )    # parent
   {
      while ( waitpid( $child_pid, 0 ) == -1 ) { }
      my $x = $?;

      die "FAILURE in run, (info=$!, ret=$x)\n"
        if ( $x != 0 );
   }
   else
   {
      chdir($chdir)
        if ($chdir);

      my $ret = &$call;
      exit($ret);
   }
}
