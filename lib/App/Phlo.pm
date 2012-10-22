package App::Phlo;

use 5.006;
use strict;
use warnings;

use Path::Class;
use Digest;    #Digest implementation seems to be the fastest for MD5
use Digest::CRC;
use Digest::SHA1 qw( sha1_hex );
use File::Temp qw/ tempfile /;
use File::Copy qw/ cp mv /;
use Carp;

=head1 NAME

App::Phlo - The mighty Perl Hard Link Optimizer

phlo is an utility to optimize storage, by finding/replacing duplicates files by
hard link from the original file.

This is mainly useful when you have a lot of duplicates files that are only
read (CPAN modules, music files, data files...)

=head1 VERSION

Version 0.001_001   *Experimental* 

=cut

our $VERSION = '0.001_001';
$VERSION = eval $VERSION;

=head1 SYNOPSIS

App::Phlo is not supposed to be called programatically, it's more
a backend for the script 'phlo' which is supposed to be called from
the commmand line.

But basically what the script does is :

    use App::Phlo;

    my $phlo = App::Phlo->new();

    $phlo->process( { DIR => '~/perl5/perlbrew' } );


Of course many options are available, to UNhardlink duplicate
(--revert action from the script)

    use App::Phlo;

    my $phlo = App::Phlo->new( { ACTION => 'revert' });

    $phlo->process( { DIR => '~/perl5/perlbrew' } );

=head1 SUBROUTINES/METHODS

=head2 new

=cut

sub new {
    my $class   = shift;
    my $options = shift;

    my $self = bless {}, $class;

    $self->{md5}  = new Digest("MD5");
    $self->{crc}  = new Digest::CRC();
    $self->{sha1} = new Digest::SHA1();

    for my $option ( keys %$options ) {
        if ( $option =~ /action/i ) {
            $self->action( $options->{$option} );
        } elsif ( $option =~ /dir/i ) {
            $self->target( $options->{$option} );
        } elsif ( $option =~ /dryrun/i ) {
            $self->{DRYRUN} = $options->{$option};
        } elsif ( $option =~ /verbose/i ) {
            $self->{VERBOSE} = $options->{$option};
        }
    }

    $self->filter('.*');
    $self->action('hardlink');

    $self->{primary_digest}   = 'MD5';
    $self->{secondary_digest} = 'SHA1';

    return $self;
}

=head2 target ( $value )

Accessor for the target directory

=cut

sub target {
    my $self  = shift;
    my $value = shift;

    if ($value) {
        $self->{target} = Path::Class::Dir->new($value);
    }

    return $self->{target};
}

=head2 action ( $value )

Accessor for the action attribute
The $value can currently be : 'hardlink', 'unhardlink'

=cut

sub action {
    my $self  = shift;
    my $value = shift;

    croak "Action can only be 'hardlink' or 'unhardlink'" unless $value =~ /(hardlink|unhardlink)/i;

    if ($value) {
        $self->{action} = qr/$value/;
    }

    return $self->{action};
}

=head2 filter ( $value )

Accessor for the filter attribute
The $value is a regex pattern.
(whose default value is '.*')

=cut

sub filter {
    my $self  = shift;
    my $value = shift;

    if ($value) {
        $self->{filter} = qr/$value/;
    }

    return $self->{filter};
}

=head2 process_duplicate ( $digester_name, $digester, $file )

Process duplicates, according to $self->action() value

=cut

sub process_duplicate {
    my $self      = shift;
    my $original  = shift;
    my $duplicate = shift;

    if ( $self->action() =~ /hardlink/i ) {
        $self->_hardlink( $original, $duplicate ) unless $self->{DRYRUN};
    } elsif ( $self->action() =~ /hardlink/i ) {
        $self->_unhardlink( $original, $duplicate ) unless $self->{DRYRUN};
    }
}

=head2 process ( \%options )

Method to replace duplicates files by hardlink

=cut

sub process {
    my $self    = shift;
    my $options = shift;

    for my $option ( keys %$options ) {
        if ( $option =~ /dir/i ) {
            $self->target( $options->{$option} );
        }
    }

    $self->target->recurse(
        callback => sub {
            my $item = shift;

            return if $item->is_dir;

            my $name = $item->absolute;

            # Process only files whose name match the filter
            return unless $name =~ $self->filter;

            # Ignore null sized file
            return unless $item->stat->size;

            $self->{STATS}{COUNT}++;

            $self->_hash_file( 'MD5', $self->{md5}, $item );

            $self->_hash_file( 'SHA1', $self->{sha1}, $item );

            ## $self->_hash_file('crc',$self->{cdr},$item);

        }
    );

    my $primary_digest   = $self->{primary_digest};
    my $secondary_digest = $self->{secondary_digest};

    for my $duplicate ( keys %{ $self->{$primary_digest} } ) {
        if ( $#{ $self->{$primary_digest}{$duplicate} } > 1 ) {
            my @duplicates    = @{ $self->{$primary_digest}{$duplicate} };
            my $original      = shift @duplicates;
            my $original_sha1 = $self->{FILES}{$secondary_digest}{$original};
            for my $dup_file (@duplicates) {
                $self->_log("    -> dup_file $dup_file");

                if ( $self->{FILES}{$secondary_digest}{$dup_file} eq $original_sha1 ) {

                    if ( $self->{DRYRUN} ) {
                        $self->_log("    -> cancelled (by --dryrun option)");

                    } else {
                        $self->_hardlink( $original, $dup_file ) unless $self->{DRYRUN};
                    }

                } else {
                    die "Weird : $original and $dup_file ($primary_digest hash collision)";
                }
            }
            print $/, $/;

        }
    }
}

=head2 _log

=cut

sub _log {
    my $self = shift;
    my @msg  = @_;

    return unless $self->{VERBOSE};

    warn @msg;

    # print STDERR @msg;
}

=head2 _hash_file ( $digester_name, $digester, $file )

Hash a $file, using $digester which uses a $digester_name algorithm 

=cut

sub _hash_file {
    my $self          = shift;
    my $digester_name = shift;
    my $digester      = shift;
    my $file          = shift;

    my $name = $file->absolute;

    $digester->addfile( $file->open );

    my $digest = $digester->hexdigest;

    push @{ $self->{$digester_name}{$digest} }, $name;
    $self->{FILES}{$digester_name}{$name} = $digest;
    $self->_log("$name hashed ($digester_name)");

}

=head2 _hardlink ($src, $dst)

Hard link $src to $dst

=cut

sub _hardlink {
    my $self = shift;
    my $src  = shift;
    my $dst  = shift;

    # # Check source still present
    # next unless -e $src;

    # $self->_log("hardlinking $src -> $dst");

    # # Remove dst file
    # unlink $dst;

    # # try to hardlink src to dst
    # link $src, $dst;

    $self->_log("hardlinking $src -> $dst");

    # Rename $dst to temp file
    my ( $fh, $filename ) = tempfile('phloXXXXXX') or $self->_log('Unable to find a temporary file name');
    mv( $dst, $filename ) or $self->_log("Unable to copy $dst while hardlinking");

    # try to hardlink src to dst
    link $src, $dst or $self->_log("Unable to hardlink from $src to $dst ($!)");

    # Remove temp file
    unlink $filename or $self->_log("Unable to remove tempfile after hardlink ($)");
}

=head2 _unhardlink ($dst)

Remove hardlink to $dst and replace by a copied file

=cut

sub _unhardlink {
    my $self = shift;
    my $src  = shift;
    my $dst  = shift;

    # Check source still present
    if ( !-e $dst ) {
        return;
    }

    # Check that $dst is a hardlink
    my $nlink = (stat($dst))[3];
    if ( $nlink < 2 ) {
        my $nlink = (stat($src))[3];
        if ( $nlink > 1 ) {
            # Switch $dst and $src for $dst is a hardlink
            my $tmp = $dst;
            $dst = $src;
            $src = $tmp;
        } else {
            return;
        }
    }

    # copy file
    $self->_log("UNhardlinking $dst");

    # Copy $dest to temp file
    my ( $fh, $filename ) = tempfile('phloXXXXXX') or $self->_log('Unable to find a temporary file name');
    cp( $dst, $filename ) or $self->_log("Unable to copy $dst while UNhardlinking");

    # Remove dst file
    unlink $dst or $self->_log('Unable to remove $dest while UNhardlinking');

    # Rename temfile
    mv( $filename, $dst ) or $self->_log("Unable to rename tempfile to $dst")

}

=head1 AUTHOR

Arnaud (Arhuman) Assad, C<< <arhuman at gmail.com> >>

=head1 BUGS

Tons. This is currently alpha code.

=head1 TODO

* Make the script portable (curently too much linux centric...)
* Allow a --revert action (to replace hardlink by copy)
* Add checks (file exists, is not already hardlink)
* Offer fallback mode (symlink ?)
* Configurable error mode (not enough rights, file deleted...)
* Check rights/owner before linking when executing as root ?
* More options
  + Explicitly specify source
  + primary and secondary digest algorithm (md5,sha1,crc)
  + symlinks 
  + stats (listing/space)
* Performance

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc App::Phlo

=head1 ACKNOWLEDGEMENTS

=head1 LICENSE AND COPYRIGHT

Copyright 2012 Arnaud (Arhuman) Assad.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1;    # End of App::Phlo
