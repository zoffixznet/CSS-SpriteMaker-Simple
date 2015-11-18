package CSS::SpriteMaker::Simple;

# VERSION

use Mojo::Base -base;

use Carp                  qw/croak          /;
use File::Copy            qw/copy           /;
use File::Find            qw/find           /;
use File::Temp            qw/tempdir        /;
use File::Spec::Functions qw/catdir  catfile/;
use Mojo::Util            qw/b64_encode/;
use Mojolicious;

has 'css';

sub spritify {
    my $self = shift;
    my @ignore = @{ ref $_[-1] ? pop : [] };
    @_ or croak 'Missing list of paths to search for pictures';
    my $asset_dir = $self->_gather_pics( \@ignore, @_ );

    # Set up the app
    my $s = Mojolicious->new;
    $s->mode('production');
    $s->log->level('fatal'); # disable 'info' message from AssetPack
    $s->static->paths([ catdir $asset_dir, 'public' ]);

    # AssetPack plugin will generate the CSS and the Sprite image
    $s->plugin('AssetPack');
    $s->asset( 'app.css' => 'sprites:///sprite' );

    # Fetch CSS code and embed the sprite as base64 in it
    my $css = $s->static->file( $s->asset->get('app.css') )->slurp;
    my ( $sprite_filename )
    = $css =~ /\.sprite\{background:url\(  (sprite-\w+\.png)  \)/x;

    my $sprite = $s->static->file( catfile 'packed', $sprite_filename )->slurp;
    $sprite = b64_encode $sprite, '';

    $css =~ s{\Q$sprite_filename\E}{data:image/png;base64,$sprite};

    # Modify pic classnames to avoid potential clashes
    $css =~ s{\.sprite\.(?=[\w-]+)}{.sprite.s-}g;
    $self->css( $css );

    $self;
}

sub spurt {
    my ( $self, $file ) = @_;

    Mojo::Util::spurt $self->css => $file;

    $self;
}

sub _gather_pics {
    my ( $self, $ignore, @locations ) = @_;

    my %ignore = map +( $_ => 1 ), @$ignore;
    my @pics = grep -f, @locations;
    find sub {
        return unless -f and /\.(png|gif|jpg|jpeg)$/ and not $ignore{$_};
        push @pics, $File::Find::name;
    }, grep -d, @locations;

    my $dir = tempdir CLEANUP => 1;
    mkdir catdir $dir, 'public';
    my $sprite_dir = catdir $dir, 'public', 'sprite';
    mkdir $sprite_dir
        or croak "Failed to create sprite dir [$sprite_dir]: $!";

    copy $_ => $sprite_dir for @pics;

    return $dir;
}

1;

__END__

=encoding utf8

=for stopwords Znet Zoffix distro

=head1 NAME

CSS::SpriteMaker::Simple - generate CSS sprites from a bunch of images

=head1 SYNOPSIS

    say CSS::SpriteMaker::Simple->new->spritify('pics', 'pic1.png')->css;

    # or

    CSS::SpriteMaker::Simple->new
        ->spritify('pics', 'pic1.png')->spurt('sprite.css');

    ...
        <span class="sprite s-FILENAME-OF-PIC"></span>

      <link rel="stylesheet" property="stylesheet" href="sprite.css">
    </body>
    </html>

=head1 DESCRIPTION

Generate a
L<CSS sprite|http://en.wikipedia.org/wiki/Sprite_%28computer_graphics%29#Sprites_by_CSS>
using given image files. The result is a a single chunk of CSS code, with
images base64 encoded into it.

=for pod_spiffy start warning section

This code was plucked from a project I was working on and simply quickly
packaged into a CPAN distro. As such, it currently lacks tests.
L<Patches are definitely welcome|https://github.com/zoffixznet/CSS-SpriteMaker-Simple>.

=for pod_spiffy end warning section

=head1 METHODS

=head2 C<new>

    my $s = CSS::SpriteMaker::Simple->new;

Creates and returns a new C<CSS::SpriteMaker::Simple> object.
Takes no arguments.

=head2 C<spritify>

    $s->spritify( qw/list of dirs with pics or pics/ );
    $s->spritify( qw/list of dirs with pics or pics/, [qw/ignore these/] );

Returns its invocant. Takes a list of paths and searches them for pics to
use as sprites. The last element can be an arrayref, in which case, this
will be a list of filenames (no directory portion) that will be ignored.

Will croak if no paths are given or it has trouble
creating the temporary directory to assemble the sprite in.

=head2 C<css>

    say $s->css;

Returns CSS code of the sprite. Must be called after a call to L</spritify>

=head2 C<spurt>

    say $s->spurt('sprite.css');

Write CSS code of the sprite into a file. Must be called after a call to
L</spritify>

=head1 SEE ALSO

L<Mojolicious::Plugin::AssetPack>

=for pod_spiffy hr

=head1 REPOSITORY

=for pod_spiffy start github section

Fork this module on GitHub:
L<https://github.com/zoffixznet/CSS-SpriteMaker-Simple>

=for pod_spiffy end github section

=head1 BUGS

=for pod_spiffy start bugs section

To report bugs or request features, please use
L<https://github.com/zoffixznet/CSS-SpriteMaker-Simple/issues>

If you can't access GitHub, you can email your request
to C<bug-CSS-SpriteMaker-Simple at rt.cpan.org>

=for pod_spiffy end bugs section

=head1 AUTHOR

=for pod_spiffy start author section

=for pod_spiffy author ZOFFIX

=for pod_spiffy end author section

=head1 LICENSE

You can use and distribute this module under the same terms as Perl itself.
See the C<LICENSE> file included in this distribution for complete
details.

=cut
