#!/usr/bin/env perl

use Mojolicious::Lite;

use File::Basename;
use File::Slurp;
use File::Spec::Functions;
use Text::Haml;
use Try::Tiny;

my %DEFAULT_STASH = (
    active => q{},
    %{ plugin 'Config' },
);
app->defaults(%DEFAULT_STASH);

plugin 'haml_renderer';

my $haml = Text::Haml->new;
helper haml => sub {
    my ( $self, $text ) = @_;

    my $html = $haml->render($text, %{ $self->stash });
    $html =~ s!
        (<code\s*.*?>)
        (.*?)
        (</code>)
    !
        my $pre     = $1;
        my $content = $2;
        my $post    = $3;

        my @lines = split /\n/, $content;
        my $space = q{};
        for my $i ( 0 .. $#lines ) {
            next unless $lines[$i];
            unless ($space) {
                if ( $lines[$i] =~ /^( +)/ ) {
                    $space = $1;
                }
            }
            $lines[$i] =~ s/^$space//sm;
        }

        $pre . join(qq{\n}, @lines) . $post;
    !gsmxe;

    return $html;
};

get '/' => sub {
    my $self = shift;

    my @slides = map { s/\.slide$// ? $_ : () } read_dir( app->config->{slide_dir} );
    $self->stash(
        slides => \@slides,
    );
} => 'index';

get '/s/:name' => sub {
    my $self = shift;
    my $name = $self->param('name');

    my $file = catfile(
        app->config->{slide_dir},
        "$name.slide",
    );
    return $self->render('not_found') unless -f $file;

    my $slide = try { eval scalar read_file($file) };
    return $self->render('not_found') unless $slide;

    $self->stash(
        author   => $slide->{author}   || q{},
        subject  => $slide->{subject}  || basename($file),
        sections => $slide->{sections} || q{},
    );
} => 'slide';

app->secret( app->defaults->{secret} );
app->start;

__DATA__

@@ index.html.ep
% layout 'slide';
% title 'Index of Presentaions via @keedi';
<section>
  <h2 style="margin-top: -0.7em;">Index</h2>
  <ul>
    % for my $slide (@$slides) {
      <li>
        <i class="icon-ok slide-green"></i>
        <a href="s/<%= $slide %>"> <%= $slide %> </a>
      </li>
    % }
  </ul>
</section>


@@ slide.html.ep
% layout 'slide';
% title $subject;
<!-- Slide goes here -->
        <%== haml($sections) %>


@@ layouts/slide/meta.html.haml
/ META
    %meta{:charset => "utf-8"}
    %meta{:name => "author",                                content => "Keedi Kim"}
    %meta{:name => "description",                           content => "Silide"}
    %meta{:name => "apple-mobile-web-app-capable",          content => "yes"}
    %meta{:name => "apple-mobile-web-app-status-bar-style", content => "black-translucent"}


@@ layouts/slide/css.html.haml
/ CSS
    %link{:rel => "stylesheet", :type => "text/css", :href => "http://fonts.googleapis.com/css?family=Lato:400,700,400italic,700italic"}
    %link{:rel => "stylesheet", :type => "text/css", :href => "/font-awesome/css/font-awesome.css"}
    %link{:rel => "stylesheet", :type => "text/css", :href => "/reveal/css/reveal.css"}
    %link{:rel => "stylesheet", :type => "text/css", :href => "/reveal/css/theme/default.css", id=>"theme"}
    %link{:rel => "stylesheet", :type => "text/css", :href => "/reveal/lib/css/zenburn.css"}
    %link{:rel => "stylesheet", :type => "text/css", :href => "/css/slide.css"}


@@ layouts/slide/js.html.ep
<!-- If the query includes 'print-pdf', use the PDF print sheet -->
    <script>
      document.write( '<link rel="stylesheet" href="/reveal/css/print/' + ( window.location.search.match( /print-pdf/gi ) ? 'pdf' : 'paper' ) + '.css" type="text/css" media="print">' );
    </script>


@@ layouts/slide/body-js.html.ep
<!-- javascript for fast loading -->
    <script src="/reveal/lib/js/head.min.js"></script>
    <script src="/reveal/js/reveal.min.js"></script>
    <script>
      // Full list of configuration options available here:
      // https://github.com/hakimel/reveal.js#configuration
      Reveal.initialize({
        controls: true,
        progress: true,
        history: true,

        theme: Reveal.getQueryHash().theme, // available themes are in /css/theme
        transition: Reveal.getQueryHash().transition || 'default', // default/cube/page/concave/zoom/linear/none

        // Optional libraries used to extend on reveal.js
        dependencies: [
          { src: '/reveal/lib/js/highlight.js', async: true, callback: function() { window.hljs.initHighlightingOnLoad(); } },
          { src: '/reveal/lib/js/classList.js', condition: function() { return !document.body.classList; } },
          { src: '/reveal/lib/js/showdown.js', condition: function() { return !!document.querySelector( '[data-markdown]' ); } },
          { src: '/reveal/lib/js/data-markdown.js', condition: function() { return !!document.querySelector( '[data-markdown]' ); } },
          { src: '/reveal/plugin/zoom-js/zoom.js', condition: function() { return !!document.body.classList; } },
          { src: '/socket.io/socket.io.js', async: true, condition: function() { return window.location.host === 'localhost:1947'; } },
          { src: '/reveal/plugin/speakernotes/client.js', async: true, condition: function() { return window.location.host === 'localhost:1947'; } }
        ]
      });
    </script>


@@ layouts/slide/google-analytics.html.ep
<!-- google analytics -->
    <script type="text/javascript">
      var gaJsHost = (("https:" == document.location.protocol) ? "https://ssl." : "http://www.");
      document.write(unescape("%3Cscript src='" + gaJsHost + "google-analytics.com/ga.js' type='text/javascript'%3E%3C/script%3E"));
    </script>
    <script type="text/javascript">
      try {
        var pageTracker = _gat._getTracker("<%= $google_analytics %>");
        pageTracker._trackPageview();
      } catch(err) {}
    </script>


@@ layouts/slide.html.haml
!!! 5
%html
  %head
    %title= title
    = include 'layouts/slide/meta'
    = include 'layouts/slide/css'
    = include 'layouts/slide/js'

  %body
    .reveal
      .slides
        = content
    = include 'layouts/slide/body-js'
    = include 'layouts/slide/google-analytics'


@@ not_found.html.haml
- layout 'slide';
- title '404 Not Found';
/ Slide goes here
        %section
          %h1 404 Not Found
          %h3
            Sorry, an error has occured,
            %br/
            Requested page not found!
