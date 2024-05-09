#!/usr/bin/perl

use strict;
use Getopt::Long;

my $llvmRepo         = "https://github.com/llvm/llvm-project.git";
my $llvmBranch       = "release/15.x";
my $buildType        = "Release";
my $cmakeExtraArgs   = "";
my $skipCheckout;
my $platform         = "linux";
my $architecture     = `uname -m`; chomp ($architecture);
my $rootDir          = `pwd`; chomp ($rootDir);
my $hostOS           = `uname`; chomp ($hostOS);
my $cmakeBuildSystem = "Ninja";
my $targetsToBuild   = "X86;ARM;AArch64;WebAssembly";
my $buildTools       = "OFF";
my $ndk;
my $androidVersion   = "26";
my $verbose;
my $cmakePrefix      = "";
my $enableAssertions = "ON";
my $enableRTTI       = "ON";
my $projectsToBuild  = "llvm;polly";
my $staticRuntime;

if ($architecture eq "x86_64")
{
    $architecture = "x64";
}

GetOptions ("build-type=s"     => \$buildType,
            "architecture=s"   => \$architecture,
            "platform=s"       => \$platform,
            "targetsToBuild=s" => \$targetsToBuild,
            "skip-checkout"    => \$skipCheckout,
            "verbose"          => \$verbose,
            "NDK=s"            => \$ndk,
            "androidVersion=s" => \$androidVersion,
            "build-tools=s"    => \$buildTools,
            "static-runtime"   => \$staticRuntime);

if (defined $ndk)
{
    $platform = "android";
    my $abi;

    if ($architecture eq "arm64")
    {
        $abi = "arm64-v8a";
    }
    else
    {
        print "Unsupported architecture (${$architecture}) on Android\n";
        exit (1);
    }

    $cmakeExtraArgs = "-DCMAKE_SYSTEM_NAME=Android -DCMAKE_SYSTEM_VERSION=${androidVersion} -DCMAKE_ANDROID_ARCH_ABI=${abi} -DCMAKE_ANDROID_NDK=${ndk} -DANDROID_ALLOW_UNDEFINED_SYMBOLS=ON";
}
elsif ($platform eq "wasm")
{
    if ($hostOS ne "Linux")
    {
        print "wasm/empscripten build only works on linux for now\n";
        exit (1);
    }

    print "Building with emscripten\n";
    $architecture = "wasm32";
    $targetsToBuild = "WebAssembly";
    $cmakePrefix = 'CXXFLAGS="-Dwait4=__syscall_wait4" emcmake';
    $cmakeExtraArgs = "-DLLVM_TABLEGEN=${rootDir}/release/linux/x64/bin/llvm-tblgen -DCMAKE_CROSSCOMPILING=True -DLLVM_DEFAULT_TARGET_TRIPLE=wasm32-wasi -DLLVM_ENABLE_THREADS=OFF -DLLVM_ENABLE_BACKTRACES=OFF -DLLVM_ENABLE_UNWIND_TABLES=OFF -DLLVM_ENABLE_CRASH_OVERRIDES=OFF -DLLVM_ENABLE_LIBXML2=OFF -DLLVM_ENABLE_LIBEDIT=OFF -DLLVM_ENABLE_LIBPFM=OFF -DLLVM_BUILD_STATIC=ON -DCMAKE_SKIP_RPATH=ON -DCMAKE_SKIP_INSTALL_RPATH=ON -DLLVM_ENABLE_PIC=OFF -DLLVM_ENABLE_ZLIB=OFF";
    $enableAssertions = "OFF";
    $enableRTTI = "OFF";
    $projectsToBuild = "llvm";
}
elsif ($hostOS eq "Linux")
{
    if ($architecture eq "arm64")
    {
        $ENV{"CXX"}             = "aarch64-linux-gnu-g++-8";
        $ENV{"CC"}              = "aarch64-linux-gnu-gcc-8";
        $ENV{"PKG_CONFIG_PATH"} = "/usr/aarch64-linux-gnu/lib/pkgconfig";
        $ENV{"TARGET_ARCH"}     = "-march=armv8-a";

        $cmakeExtraArgs = "-DLLVM_TABLEGEN=${rootDir}/release/linux/x64/bin/llvm-tblgen -DCMAKE_CROSSCOMPILING=True -DLLVM_TARGET_ARCH=ARM -DLLVM_DEFAULT_TARGET_TRIPLE=aarch64-linux-gnu -DLLVM_HOST_TRIPLE=aarch64-linux-gnu";
    }

    if ($architecture eq "arm32")
    {
        $ENV{"CXX"}             = "arm-linux-gnueabihf-g++-8";
        $ENV{"CC"}              = "arm-linux-gnueabihf-gcc-8";
        $ENV{"PKG_CONFIG_PATH"} = "/usr/arm-linux-gnueabihf/lib/pkgconfig";
        $ENV{"TARGET_ARCH"}     = "-march=armv7-a -mfpu=vfpv3-d16 -mfloat-abi=hard";

        $cmakeExtraArgs = "-DLLVM_TABLEGEN=${rootDir}/release/linux/x64/bin/llvm-tblgen -DCMAKE_CROSSCOMPILING=True -DLLVM_TARGET_ARCH=ARM -DLLVM_DEFAULT_TARGET_TRIPLE=armv7l-linux-gnueabihf -DLLVM_HOST_TRIPLE=armv7l-linux-gnueabihf";
    }
}
elsif ($hostOS eq "Darwin")
{
    $platform = "osx";
    $cmakeExtraArgs = "-DCMAKE_OSX_DEPLOYMENT_TARGET=\"10.15\"";
}
elsif (substr ($hostOS, 0, 9) eq "CYGWIN_NT")
{
    $platform = "win";
    $cmakeBuildSystem = "Visual Studio 16 2019";
    $rootDir = `cygpath -m $rootDir`;
    chomp ($rootDir);

    if ($architecture eq "arm64")
    {
        $cmakeExtraArgs = "-Thost=x64 -A arm64 -DLLVM_TABLEGEN=${rootDir}/release/win/x64/bin/llvm-tblgen.exe -DLLVM_NM=${rootDir}/build/win/x64/Release/bin/llvm-nm.exe -DLLVM_TARGET_ARCH=ARM -DCMAKE_CROSSCOMPILING=True -DLLVM_HOST_TRIPLE=arm64-pc-windows-msvc -DLLVM_DEFAULT_TARGET_TRIPLE=arm64-pc-windows-msvc";
    }
    else
    {
        $cmakeExtraArgs = "-Thost=x64";
    }

    if ($staticRuntime)
    {
        $cmakeExtraArgs .= " -DLLVM_USE_CRT_RELEASE=MT";
        $platform = "win-static";
    }
}
else
{
    print "Unsupported OS ${hostOS}/${architecture}\n";
    exit (1);
}

if ($verbose)
{
    $cmakeExtraArgs = $cmakeExtraArgs . " -DCMAKE_VERBOSE_MAKEFILE=ON";
}

my $sourceDir    = "${rootDir}/src";
my $buildDir     = "${rootDir}/build/${platform}/${architecture}";
my $releaseDir   = "${rootDir}/release/${platform}/${architecture}";

sub execute ($)
{
    my ($command) = @_;
    print "> $command\n";
    if (system ($command) != 0)
    {
        die "command failed";
    }
}

sub setDir ($)
{
    my ($dir) = @_;
    print "> cd ${dir}\n";
    chdir $dir;
}

sub cloneLLVM()
{
    execute ("mkdir -p ${sourceDir}");

    if (-e "${sourceDir}/.git")
    {
        execute ("cd ${sourceDir}; git pull");
    }
    else
    {
        execute ("git clone ${llvmRepo} ${sourceDir}");
    }

    execute ("cd ${sourceDir}; git checkout $llvmBranch");
}

sub generateCmakePlatforms()
{
    my $platforms;

    if ($targetsToBuild =~ m/AArch64/)      { $platforms .= "set (LLVM_INCLUDE_PLATFORM_ARM64 ON)\n"; }
    if ($targetsToBuild =~ m/X86/)          { $platforms .= "set (LLVM_INCLUDE_PLATFORM_X64 ON)\n"; }
    if ($targetsToBuild =~ m/ARM/)          { $platforms .= "set (LLVM_INCLUDE_PLATFORM_ARM32 ON)\n"; }
    if ($targetsToBuild =~ m/WebAssembly/)  { $platforms .= "set (LLVM_INCLUDE_PLATFORM_WASM ON)\n"; }
    if ($targetsToBuild =~ m/Hexagon/)      { $platforms .= "set (LLVM_INCLUDE_PLATFORM_HEXAGON ON)\n"; }
    if ($targetsToBuild =~ m/RISCV/)        { $platforms .= "set (LLVM_INCLUDE_PLATFORM_RISCV ON)\n"; }

    open (P, ">", "${releaseDir}/cmake_platforms");
    print P $platforms;
    close (P);
}

sub buildLLVM()
{
    execute ("mkdir -p ${buildDir}");
    execute ("mkdir -p ${releaseDir}");

    setDir ("${buildDir}");

    execute ("${cmakePrefix} cmake -G \"${cmakeBuildSystem}\" -DCMAKE_BUILD_TYPE=${buildType} -DLLVM_ENABLE_ZSTD=OFF -DLLVM_ENABLE_ASSERTIONS=${enableAssertions} -DLLVM_ENABLE_RTTI=${enableRTTI} -DLLVM_INCLUDE_EXAMPLES=OFF -DLLVM_INCLUDE_TESTS=OFF -DLLVM_INCLUDE_DOCS=OFF -DLLVM_TARGETS_TO_BUILD=\"${targetsToBuild}\" -DLLVM_ENABLE_PROJECTS=\"${projectsToBuild}\" -DLLVM_ENABLE_TERMINFO=OFF -DLLVM_INSTALL_UTILS=OFF -DLLVM_BUILD_TOOLS=${buildTools} -DCMAKE_INSTALL_PREFIX=${releaseDir} ${cmakeExtraArgs} ${sourceDir}/llvm");
    execute ("cmake --build . --config ${buildType} --target install");
}

if (! defined $skipCheckout)
{
    cloneLLVM();
}

buildLLVM();
generateCmakePlatforms();