package App::GitGot::Repo::Git;
# ABSTRACT: Git repo objects
use Moose;
extends 'App::GitGot::Repo';
use 5.010;

use namespace::autoclean;
use Git::Wrapper;
use Test::MockObject;
use Try::Tiny;

has '+type' => ( default => 'git' );

has '_wrapper' => (
  is         => 'ro' ,
  isa        => 'Git::Wrapper' ,
  lazy_build => 1 ,
  handles    => [ qw/
                      cherry
                      clone
                      config
                      pull
                      remote
                      status
                      symbolic_ref
                    / ] ,
);

sub _build__wrapper {
  my $self = shift;

  # for testing...
  if ( $ENV{GITGOT_FAKE_GIT_WRAPPER} ) {
    my $mock = Test::MockObject->new;
    $mock->set_isa( 'Git::Wrapper' );
    foreach my $method ( qw/ cherry clone config pull remote
                             status symbolic_ref / ) {
      $mock->mock( $method => sub { return "Called $method" });
    }
    return $mock
  }
  else {
    return Git::Wrapper->new( $self->path )
      or die "Can't make Git::Wrapper";
  }
}


=method current_branch

Returns the current branch checked out by this repository object.

=cut
sub current_branch {
  my $self = shift;

  my $branch;

  try {
    ( $branch ) = $self->symbolic_ref( 'HEAD' );
    $branch =~ s|^refs/heads/||;
  }
  catch {
    die $_ unless $_ && $_->isa('Git::Wrapper::Exception')
      && $_->error eq "fatal: ref HEAD is not a symbolic ref\n"
  };

  return $branch;
}

=method current_remote_branch

Returns the remote branch for the branch currently checked out by this repo
object, or 0 if that information can't be extracted (if, for example, the
branch doesn't have a remote.)

=cut
sub current_remote_branch {
  my( $self ) = shift;

  my $remote;

  if ( my $branch = $self->current_branch ) {
    try {
      ( $remote ) = $self->config( "branch.$branch.remote" );
    }
    catch {
      ## not the most informative return....
      return 0 if $_ && $_->isa('Git::Wrapper::Exception') && $_->{status} eq '1';
    };
  }

  return $remote;
}

__PACKAGE__->meta->make_immutable;
1;