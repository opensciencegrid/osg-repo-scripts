#!/usr/bin/perl -w
use strict;

# generate list of new-style osg-tags, mapping to old-style tag name
# if the corresponding new-style tag is not present

my %tag_map;
my @tags = <>;
chomp for @tags;

# first look for old-style tags, mapping to new-style
for my $tag (@tags) {
  if ($tag =~ /^(el[56]) - osg (-(upcoming))? -
                (contrib|development|release|testing)$/x) {
    my $new_tag = "osg-" . ($3||"3.1") . "-$1-$4";
    $tag_map{$new_tag} = $tag;
    #print "OLD: $tag\n";
  }
}

# look for new-style tags, replacing mapping from corresponding old-style ones
for my $tag (@tags) {
  if ($tag =~ /^osg - ([0-9]+\.[0-9]+|upcoming) - (el[5-9]) -
                (contrib|development|release|testing)$/x) {
    $tag_map{$tag} = undef;
    #print "NEW: $tag\n";
  }
}

for my $tag (sort keys %tag_map) {
  if (defined $tag_map{$tag}) {
    print "$tag:$tag_map{$tag}\n";
  } else {
    print "$tag\n";
  }
}

