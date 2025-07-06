# backend for PatchbayLabs
# 29.10.24 by daniel boehringer
# Copyright 2024, All rights reserved.
#

use Mojolicious::Lite;
use Mojo::Pg;
use Data::Dumper;

no warnings 'uninitialized';

# helper pg => sub { state $pg = Mojo::Pg->new('postgresql://postgres@localhost/ui_builder') };

# turn browser cache off
hook after_dispatch => sub {
    my $tx = shift;
    my $e = Mojo::Date->new(time-100);
    $tx->res->headers->header(Expires => $e);
    $tx->res->headers->header('X-ARGOS-Routing' => '3036');
};


###################################################################
# main()

app->config(hypnotoad => {listen => ['http://*:3036'], workers => 2, heartbeat_timeout => 12000, inactivity_timeout => 12000});

app->start;
