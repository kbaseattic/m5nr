package m5nr;

use strict;
use warnings;
no warnings('once');

use JSON;
use LWP::UserAgent;
use URI::Escape;
use Digest::MD5;
use M5NR_Conf;

# Override parent constructor
sub new {
    my ($class, $params) = @_;

    # set variables
    my $agent = LWP::UserAgent->new;
    my $json  = JSON->new;
    $json = $json->utf8();
    $json->max_size(0);
    $json->allow_nonref;
    my $html_messages = { 200 => "OK",
                          201 => "Created",
                          204 => "No Content",
                          400 => "Bad Request",
                          401 => "Unauthorized",
    		              404 => "Not Found",
    		              416 => "Request Range Not Satisfiable",
    		              500 => "Internal Server Error",
    		              501 => "Not Implemented",
    		              503 => "Service Unavailable",
    		              507 => "Storing object failed",
    		              -32602 => "Invalid params",
    		              -32603 => "Internal error"
    		              };
    # create object
    my $self = {
        format        => "application/json",
        agent         => $agent,
        json          => $json,
        cgi           => $params->{cgi},
        rest          => $params->{rest_parameters} || [],
        method        => $params->{method},
        submethod     => $params->{submethod},
        resource      => $params->{resource},
        json_rpc      => $params->{json_rpc} ? $params->{json_rpc} : 0,
        json_rpc_id   => ($params->{json_rpc} && exists($params->{json_rpc_id})) ? $params->{json_rpc_id} : undef,
        html_messages => $html_messages,
        name          => "m5nr",
        request       => { sources => 1, accession => 1, md5 => 1, function => 1, organism => 1, sequence => 1 },
        attributes    => { sources  => { data    => [ 'hash', [{'key' => ['string', 'source name'],
                                                                 'value' => ['string', 'source type']}, 'source hash'] ],
                                          version => [ 'integer', 'version of the object' ],
                                          url     => [ 'uri', 'resource location of this object instance' ] },
                            annotation => { next   => ["uri","link to the previous set or null if this is the first set"],
                                            prev   => ["uri","link to the next set or null if this is the last set"],
                                            limit  => ["integer","maximum number of data items returned, default is 10"],
                                            offset => ["integer","zero based index of the first returned data item"],
                                            total_count => ["integer","total number of available data items"],
                                            version => [ 'integer', 'version of the object' ],
                                            url  => [ 'uri', 'resource location of this object instance' ],
                                            data => [ 'list', ['object', [{'accession'   => [ 'string', 'unique identifier given by source' ],
                                                                           'md5'         => [ 'string', 'md5 checksum - M5NR ID' ],
                                                                           'function'    => [ 'string', 'function annotation' ],
                                                                           'organism'    => [ 'string', 'organism annotation' ],
                                                                           'ncbi_tax_id' => [ 'int', 'organism ncbi tax_id' ],
                                                                           'type'        => [ 'string', 'source type' ],
                                                                           'source'      => [ 'string', 'source name' ]}, "annotation object"]] ] }
             	          }
    };
    bless $self, $class;
    return $self;
}

# get functions for class variables
sub agent {
    my ($self) = @_;
    return $self->{agent};
}
sub json {
    my ($self) = @_;
    return $self->{json};
}
sub cgi {
    my ($self) = @_;
    return $self->{cgi};
}
sub rest {
    my ($self) = @_;
    return $self->{rest};
}
sub method {
    my ($self) = @_;
    return $self->{method};
}
sub submethod {
    my ($self) = @_;
    return $self->{submethod};
}
sub json_rpc {
    my ($self) = @_;
    return $self->{json_rpc};
}
sub json_rpc_id {
    my ($self) = @_;
    return $self->{json_rpc_id};
}
sub html_messages {
    my ($self) = @_;
    return $self->{html_messages};
}
sub name {
    my ($self) = @_;
    return $self->{name};
}
sub attributes {
    my ($self) = @_;
    return $self->{attributes};
}

# get / set functions for class variables
sub format {
    my ($self, $format) = @_;
    if ($format) {
        $self->{format} = $format;
    }
    return $self->{format};
}


# get cgi header
sub header {
    my ($self, $status) =  @_;
    return $self->cgi->header( -type => $self->format,
	                           -status => $status,
	                           -Access_Control_Allow_Origin => '*' );
}

# resource is called without any parameters
# this method must return a description of the resource
sub info {
  my ($self) = @_;
  my $content = { 'name'          => $self->name,
		  'url'           => $self->cgi->url."/".$self->name,
		  'description'   => "M5NR provides data through a comprehensive non-redundant protein / rRNA database",
		  'type'          => 'object',
		  'documentation' => $self->cgi->url.'/api.html#'.$self->name,
		  'requests'      => [ { 'name'        => "info",
					             'request'     => $self->cgi->url."/".$self->name,
					             'description' => "Returns description of parameters and attributes.",
					             'method'      => "GET",
					             'type'        => "synchronous",
					             'attributes'  => "self",
					             'parameters'  => { 'options'  => {},
							                        'required' => {},
							                        'body'     => {} }
				       },
				       { 'name'        => "sources",
					     'request'     => $self->cgi->url."/".$self->name."/sources",
					     'example'     => [ $self->cgi->url."/".$self->name."/sources",
         				                    'retrieve all data sources for M5NR' ],
					     'description' => "Return all sources in M5NR",
					     'method'      => "GET",
					     'type'        => "synchronous",  
					     'attributes'  => $self->{attributes}{sources},
					     'parameters'  => { 'options'  => {},
							                'required' => {},
							                'body'     => {} }
				       },
				       { 'name'        => "accession",
   					     'request'     => $self->cgi->url."/".$self->name."/accession/{id}",
   					     'description' => "Return annotation of given source protein ID",
   					     'example'     => [ $self->cgi->url."/".$self->name."/accession/YP_003268079.1",
          				                    "retrieve M5NR data for accession ID 'YP_003268079.1'" ],
   					     'method'      => "GET",
   					     'type'        => "synchronous",  
   					     'attributes'  => $self->{attributes}{annotation},
   					     'parameters'  => { 'options'  => { 'limit'  => ['integer','maximum number of items requested'],
                                                            'offset' => ['integer','zero based index of the first data object to be returned'],
                                                            "order"  => ["string","name of the attribute the returned data is ordered by"]
    					                                  },
   							                'required' => { "id" => ["string", "unique identifier from source DB"] },
   							                'body'     => {} }
   				       },
				       { 'name'        => "md5",
   					     'request'     => $self->cgi->url."/".$self->name."/md5/{id}",
   					     'description' => "Return annotation(s) or sequence of given md5sum (M5NR ID)",
   					     'example'     => [ $self->cgi->url."/".$self->name."/md5/000821a2e2f63df1a3873e4b280002a8?source=InterPro",
           				                    "retrieve InterPro M5NR data for md5sum '000821a2e2f63df1a3873e4b280002a8'" ],
   					     'method'      => "GET",
   					     'type'        => "synchronous",  
   					     'attributes'  => $self->{attributes}{annotation},
   					     'parameters'  => { 'options'  => { 'source' => ['string','source name to restrict search by'],
   					                                        'limit'  => ['integer','maximum number of items requested'],
                                                            'offset' => ['integer','zero based index of the first data object to be returned'],
                                                            "order"  => ["string","name of the attribute the returned data is ordered by"],
                                                            'sequence' => ['boolean', "if true return sequence output, else return annotation output, default is false"]
   					                                      },
   							                'required' => { "id" => ["string", "unique identifier in form of md5 checksum"] },
   							                'body'     => {} }
   				       },
				       { 'name'        => "function",
   					     'request'     => $self->cgi->url."/".$self->name."/function/{text}",
   					     'description' => "Return annotations for function names containing the given text",
   					     'example'     => [ $self->cgi->url."/".$self->name."/function/sulfatase?source=GenBank",
             				                "retrieve GenBank M5NR data for function names containing string 'sulfatase'" ],
   					     'method'      => "GET",
   					     'type'        => "synchronous",  
   					     'attributes'  => $self->{attributes}{annotation},
   					     'parameters'  => { 'options'  => { 'source' => ['string','source name to restrict search by'],
   					                                        'limit'  => ['integer','maximum number of items requested'],
                                                            'offset' => ['integer','zero based index of the first data object to be returned'],
                                                            "order"  => ["string","name of the attribute the returned data is ordered by"]
    					                                  },
   							                'required' => { "text" => ["string", "text string of partial function name"] },
   							                'body'     => {} }
   				       },
   				       { 'name'        => "organism",
   					     'request'     => $self->cgi->url."/".$self->name."/organism/{text}",
   					     'description' => "Return annotations for organism names containing the given text",
   					     'example'     => [ $self->cgi->url."/".$self->name."/organism/akkermansia?source=KEGG",
              				                "retrieve KEGG M5NR data for organism names containing string 'akkermansia'" ],
   					     'method'      => "GET",
   					     'type'        => "synchronous",  
   					     'attributes'  => $self->{attributes}{annotation},
   					     'parameters'  => { 'options'  => { 'source' => ['string','source name to restrict search by'],
   					                                        'limit'  => ['integer','maximum number of items requested'],
                                                            'offset' => ['integer','zero based index of the first data object to be returned'],
                                                            "order"  => ["string","name of the attribute the returned data is ordered by"]
     					                                  },
   							                'required' => { "text" => ["string", "text string of partial organism name"] },
   							                'body'     => {} }
   				       },
   				       { 'name'        => "sequence",
   					     'request'     => $self->cgi->url."/".$self->name."/sequence/{text}",
   					     'description' => "Return annotation(s) for md5sum (M5NR ID) of given sequence",
   					     'example'     => [ $self->cgi->url."/".$self->name."/sequence/MAGENHQWQGSIL?source=TrEMBL",
            				                "retrieve TrEMBL M5NR data for md5sum of sequence 'MAGENHQWQGSIL'" ],
   					     'method'      => "GET",
   					     'type'        => "synchronous",  
   					     'attributes'  => $self->{attributes}{annotation},
   					     'parameters'  => { 'options'  => { 'source' => ['string','source name to restrict search by'],
   					                                        'limit'  => ['integer','maximum number of items requested'],
                                                            'offset' => ['integer','zero based index of the first data object to be returned'],
                                                            "order"  => ["string","name of the attribute the returned data is ordered by"]
      					                                  },
   							                'required' => { "text" => ["string", "text string of protein sequence"] },
   							                'body'     => {} }
   				       },
                           { 'name'        => "accession",
      					     'request'     => $self->cgi->url."/".$self->name."/accession",
      					     'description' => "Return annotations of given source protein IDs",
      					     'example'     => [ 'curl -X POST -d \'{"order":"function","data":["YP_003268079.1","COG1764"]}\' "'.$self->cgi->url."/".$self->name.'/accession"',
               				                    "retrieve M5NR data for accession IDs 'YP_003268079.1' and 'COG1764' ordered by function" ],
      					     'method'      => "POST",
      					     'type'        => "synchronous",  
      					     'attributes'  => $self->{attributes}{annotation},
      					     'parameters'  => { 'body'     => { 'data'   => ['list',["string","unique identifier from source DB"]],
      					                                        'limit'  => ['integer','maximum number of items requested'],
                                                                'offset' => ['integer','zero based index of the first data object to be returned'],
                                                                "order"  => ["string","name of the attribute the returned data is ordered by"]
       					                                      },
      							                'required' => {},
      							                'options'  => {} }
      				       },
   				           { 'name'        => "md5",
      					     'request'     => $self->cgi->url."/".$self->name."/md5",
      					     'description' => "Return annotations of given md5sums (M5NR ID)",
      					     'example'     => [ 'curl -X POST -d \'{"source":"InterPro","data":["000821a2e2f63df1a3873e4b280002a8","15bf1950bd9867099e72ea6516e3d602"]}\' "'.$self->cgi->url."/".$self->name.'/md5"',
                				                "retrieve InterPro M5NR data for md5s '000821a2e2f63df1a3873e4b280002a8' and '15bf1950bd9867099e72ea6516e3d602'" ],
      					     'method'      => "POST",
      					     'type'        => "synchronous",  
      					     'attributes'  => $self->{attributes}{annotation},
      					     'parameters'  => { 'body'     => { 'data'   => ['list',["string","unique identifier in form of md5 checksum"]],
      					                                        'source' => ['string','source name to restrict search by'],
      					                                        'limit'  => ['integer','maximum number of items requested'],
                                                                'offset' => ['integer','zero based index of the first data object to be returned'],
                                                                "order"  => ["string","name of the attribute the returned data is ordered by"]
      					                                      },
      							                'required' => {},
      							                'options'  => {} }
      				       },
   				           { 'name'        => "function",
      					     'request'     => $self->cgi->url."/".$self->name."/function",
      					     'description' => "Return annotations for function names containing the given texts",
      					     'example'     => [ 'curl -X POST -d \'{"source":"GenBank","limit":50,"data":["sulfatase","phosphatase"]}\' "'.$self->cgi->url."/".$self->name.'/function"',
                  				                "retrieve top 50 GenBank M5NR data for function names containing string 'sulfatase' or 'phosphatase'" ],
      					     'method'      => "POST",
      					     'type'        => "synchronous",  
      					     'attributes'  => $self->{attributes}{annotation},
      					     'parameters'  => { 'body'     => { 'data'   => ['list',["string","text string of partial function name"]],
      					                                        'source' => ['string','source name to restrict search by'],
      					                                        'limit'  => ['integer','maximum number of items requested'],
                                                                'offset' => ['integer','zero based index of the first data object to be returned'],
                                                                "order"  => ["string","name of the attribute the returned data is ordered by"]
       					                                      },
      							                'required' => {},
      							                'options'  => {} }
      				       },
      				       { 'name'        => "organism",
      					     'request'     => $self->cgi->url."/".$self->name."/organism",
      					     'description' => "Return annotations for organism names containing the given texts",
      					     'example'     => [ 'curl -X POST -d \'{"source":"KEGG","order":"accession","data":["akkermansia","yersinia"]}\' "'.$self->cgi->url."/".$self->name.'/organism"',
                   				                "retrieve KEGG M5NR data (ordered by accession ID) for organism names containing string 'akkermansia' or 'yersinia'" ],
      					     'method'      => "POST",
      					     'type'        => "synchronous",  
      					     'attributes'  => $self->{attributes}{annotation},
      					     'parameters'  => { 'body'     => { 'data'   => ['list',["string","text string of partial organism name"]],
      					                                        'source' => ['string','source name to restrict search by'],
      					                                        'limit'  => ['integer','maximum number of items requested'],
                                                                'offset' => ['integer','zero based index of the first data object to be returned'],
                                                                "order"  => ["string","name of the attribute the returned data is ordered by"]
        					                                  },
      							                'required' => {},
      							                'options'  => {} }
      				       },
      				       { 'name'        => "sequence",
      					     'request'     => $self->cgi->url."/".$self->name."/sequence",
      					     'description' => "Return annotations for md5s (M5NR ID) of given sequences",
      					     'example'     => [ 'curl -X POST -d \'{"source":"KEGG","order":"source","data":["MAGENHQWQGSIL","MAGENHQWQGSIL"]}\' "'.$self->cgi->url."/".$self->name.'/sequence"',
                 				                "retrieve M5NR data ordered by source for sequences 'MAGENHQWQGSIL' and 'MAGENHQWQGSIL'" ],
      					     'method'      => "POST",
      					     'type'        => "synchronous",  
      					     'attributes'  => $self->{attributes}{annotation},
      					     'parameters'  => { 'body'     => { 'data'   => ['list',["string","text string of protein sequence"]],
      					                                        'source' => ['string','source name to restrict search by'],
      					                                        'limit'  => ['integer','maximum number of items requested'],
                                                                'offset' => ['integer','zero based index of the first data object to be returned'],
                                                                "order"  => ["string","name of the attribute the returned data is ordered by"]
         					                                  },
      							                'required' => {},
      							                'options'  => {} }
      				       }
   				       ]
		};
  $self->return_data($content);
}

# method to parse parameters and decide which requests to process
sub request {
    my ($self) = @_;

    my $seq = $self->cgi->param('sequence') ? 1 : 0;

    # determine sub-module to use
    if (scalar(@{$self->rest}) == 0) {
        $self->info();
    } elsif ($self->rest->[0] eq 'sources') {
        $self->sources();
    } elsif (($self->rest->[0] eq 'md5') && $self->rest->[1] && $seq && ($self->method eq 'GET')) {
        $self->instance($self->rest->[1]);
    } elsif ((scalar(@{$self->rest}) > 1) && $self->rest->[1] && ($self->method eq 'GET')) {
        $self->query($self->rest->[0], $self->rest->[1]);
    } elsif ((scalar(@{$self->rest}) == 1) && ($self->method eq 'POST')) {
        $self->query($self->rest->[0]);
    } else {
        $self->info();
    }
}

# return source data
sub sources {
    my ($self) = @_;
    
    # build query
    my $fields = ['source', 'type'];
    my $query  = 'source%3A*&group=true&group.field=source';
    my $result = $self->get_solr_query('GET', $M5NR_Conf::m5nr_solr, $M5NR_Conf::m5nr_collect, $query, undef, 0, 25, $fields);
    my $data   = {};
    
    foreach my $group (@{$result->{source}{groups}}) {
        my $set = $group->{doclist}{docs}[0];
        $data->{$set->{source}} = $set->{type};
    }
    
    my $obj = { data => $data, version => 1, url => $self->cgi->url };
    $self->return_data($obj);
}

# return data: sequence object for accession or md5
sub instance {
    my ($self, $item) = @_;
    
    my $clean = $self->clean_md5($item);
    my $data = { md5 => $clean, sequence => $self->md52sequence($item) };
    my $url = $self->cgi->url.'/m5nr/md5/'.$item.'?sequence=1';
    my $obj = { data => $data, version => 1, url => $url };
    $self->return_data($obj);
}

# return query data: annotation object
sub query {
    my ($self, $type, $item) = @_;
    
    # paramaters
    my $source = $self->cgi->param('source') ? $self->cgi->param('source') : undef;
    my $limit  = $self->cgi->param('limit')  ? $self->cgi->param('limit')  : 10;
    my $offset = $self->cgi->param('offset') ? $self->cgi->param('offset') : 0;
    my $order  = $self->cgi->param('order')  ? $self->cgi->param('order')  : undef;
    
    # build data / url
    my $post = ($self->method eq 'POST') ? 1 : 0;
    my $data = [];
    my $path = '';
    
    if ($post) {
        my $post_data = $self->cgi->param('POSTDATA') ? $self->cgi->param('POSTDATA') : join("", $self->cgi->param('keywords'));
        # all options sent as post data
        if ($post_data) {
            eval {
                my $json_data = $self->json->decode($post_data);
                if (exists $json_data->{source}) { $source = $json_data->{source}; }
                if (exists $json_data->{limit})  { $limit  = $json_data->{limit}; }
                if (exists $json_data->{offset}) { $offset = $json_data->{offset}; }
                if (exists $json_data->{order})  { $order  = $json_data->{order}; }
                $data = $json_data->{data};
            };
        # data sent in post form
        } elsif ($self->cgi->param('data')) {
            eval {
                @$data = split(/;/, $self->cgi->param('data'));
            };
        } else {
            $self->return_data( {"ERROR" => "POST request missing data"}, 400 );
        }
        if ($@ || (@$data == 0)) {
            $self->return_data( {"ERROR" => "unable to obtain POSTed data: ".$@}, 500 );
        }
        $path = '/'.$type;
    } else {
        $data = [$item];
        $path = '/'.$type.'/'.$item;
    }
    
    my $url = $self->cgi->url.'/m5nr'.$path.'?limit='.$limit.'&offset='.$offset;
    if ($source && ($type ne 'accession')) {
        $url .= '&source='.$source;
    }
    
    # strip wildcards
    map { $_ =~ s/\*//g } @$data;

    # get md5 for sequence
    if ($type eq 'sequence') {
        foreach my $d (@$data) {
            $d =~ s/\s+//sg;
            $d = Digest::MD5::md5_hex(uc $d);
        }
        $type = 'md5';
    }
    
    # get results
    my ($result, $total);
    if ($type eq 'md5') {
        my @md5s = map { $self->clean_md5($_) } @$data;
        ($result, $total) = $self->solr_data($type, \@md5s, $source, $offset, $limit, $order);
    } elsif ($type eq 'accession') {
        ($result, $total) = $self->solr_data($type, $data, undef, $offset, $limit, $order);
    } else {
        ($result, $total) = $self->solr_data($type, $data, $source, $offset, $limit, $order, 1);
    }
    my $obj = $self->check_pagination($result, $total, $limit, $path);
    $obj->{version} = 1;
    
    $self->return_data($obj);
}

sub clean_md5 {
    my ($self, $md5) = @_;
    my $clean = $md5;
    $clean =~ s/[^a-zA-Z0-9]//g;
    unless ($clean && (length($clean) == 32)) {
        $self->return_data({"ERROR" => "invalid md5 was entered ($md5)"}, 404);
    }
    return $clean;
}

sub md52sequence {
  my ($self, $md5) = @_;

  my $seq;
  eval {
      my @recs = `fastacmd -d $M5NR_Conf::m5nr_fasta -s \"lcl|$md5\" -l 0 2>&1`;
      if ((@recs < 2) || (! $recs[0]) || ($recs[0] =~ /^\s+$/) || ($recs[0] =~ /^\[fastacmd\]/)) {
          $seq = "";
      } else {
          $seq = $recs[1];
          $seq =~ s/\s+//;
      }
  };
  if ($@) {
       $self->return_data({"ERROR" => "Unable to access M5NR sequence data"}, 500);
  }
  
  return $seq;
}

sub solr_data {
    my ($self, $field, $data, $source, $offset, $limit, $order, $partial) = @_;
    
    @$data = map { uri_escape( uri_unescape($_) ) } @$data;
    if ($partial) {
        @$data = map { '*'.$_.'*' } @$data;
    }
    my $sort   = $order ? $order.'_sort+asc' : '';
    my $fields = ['source', 'function', 'accession', 'organism', 'ncbi_tax_id', 'type', 'md5'];
    my $method = (@$data > 1) ? 'POST' : 'GET';
    my $query  = join('+OR+', map { $field.'%3A'.$_ } @$data);
    if ($source) {
        $query = '('.$query.')+AND+source%3A'.$source;
    }
    return $self->get_solr_query($method, $M5NR_Conf::m5nr_solr, $M5NR_Conf::m5nr_collect, $query, $sort, $offset, $limit, $fields);
}

sub get_solr_query {
    my ($self, $method, $server, $collect, $query, $sort, $offset, $limit, $fields) = @_;
    
    my $content = undef;
    my $url  = $server.'/'.$collect.'/select';
    my $data = 'q=*%3A*&fq='.$query.'&start='.$offset.'&rows='.$limit.'&wt=json';
    if ($sort) {
        $data .= '&sort='.$sort;
    }
    if ($fields && (@$fields > 0)) {
        $data .= '&fl='.join('%2C', @$fields);
    }
    eval {
        my $res = undef;
        if ($method eq 'GET') {
            $res = $self->agent->get($url.'?'.$data);
        }
        if ($method eq 'POST') {
            $res = $self->agent->post($url, Content => $data);
        }
        $content = $self->json->decode( $res->content );
    };
    if ($@ || (! ref($content))) {
        return ([], 0);
    } elsif (exists $content->{error}) {
        $self->return_data( {"ERROR" => "Unable to query DB: ".$content->{error}{msg}}, $content->{error}{status} );
    } elsif (exists $content->{response}) {
        return ($content->{response}{docs}, $content->{response}{numFound});
    } elsif (exists $content->{grouped}) {
        return $content->{grouped};
    } else {
        $self->return_data( {"ERROR" => "Invalid SOLR return response"}, 500 );
    }
}

# check if pagination parameters are used
sub check_pagination {
    my ($self, $data, $total, $limit, $path) = @_;

    my $offset = $self->cgi->param('offset') || 0;
    my $order  = $self->cgi->param('order') || undef;
    my @params = $self->cgi->param;
    $total = int($total);
    $limit = int($limit);
    $path  = $path || "";
    
    my $total_count = $total || scalar(@$data);
    my $prev_offset = (($offset - $limit) < 0) ? 0 : $offset - $limit;
    my $next_offset = $offset + $limit;
    
    my $object = { "limit" => int($limit),
	               "offset" => int($offset),
	               "total_count" => int($total_count),
	               "data" => $data };

    # don't build urls for POST
    if ($self->method eq 'GET') {
        my $add_params  = join('&', map {$_."=".$self->cgi->param($_)} grep {$_ ne 'offset'} @params);
        $object->{url}  = $self->cgi->url."/".$self->name.$path."?$add_params&offset=$offset";
        $object->{prev} = ($offset > 0) ? $self->cgi->url."/".$self->name.$path."?$add_params&offset=$prev_offset" : undef;
        $object->{next} = (($offset < $total_count) && ($total_count > $limit)) ? $self->cgi->url."/".$self->name.$path."?$add_params&offset=$next_offset" : undef;
    }
	if ($order) {
	    $object->{order} = $order;
    }
    
	return $object;
}

# print the actual data output
sub return_data {
    my ($self, $data, $error, $cache_me) = @_;

    # default status is OK
    my $status = 200;  
  
    # if the result is an empty array, status is 204
    if (ref($data) eq "ARRAY" && scalar(@$data) == 0) {
        $status = 204;
    }

    # if an error is passed, change the return format to text 
    # and change the status code to the error code passed
    if ($error) {
        $self->format("application/json");
        $status = $error;
    }

    # check for remote procedure call
    if ($self->json_rpc) {
        # check to comply to Bob Standards
        unless (ref($data) eq 'ARRAY') {
            $data = [ $data ];
        }

        # only reply if this is not a notification
        if ($error) {
	        my $error_code = $status;
	        if ($status == 400) {
	            $status = -32602;
	        } elsif ($status == 500) {
	            $status = -32603;
	        }
	        # there was an error
	        $data = { jsonrpc => "2.0",
                      error => { code    => $error_code,
                                 message => $self->html_messages->{$status},
                                 data    => $data->[0] },
                      id => $self->json_rpc_id };
        } else {
	        # normal result
	        $data = { jsonrpc => "2.0",
		              result  => $data,
		              id      => $self->json_rpc_id };
		    # cache this!
            if ($cache_me) {
                $self->memd->set($self->url_id, $self->json->encode($data), $self->{expire});
            }
        }
        print $self->header;
        print $self->json->encode($data);
        exit 0;
    }
    else {
        # check for JSONP
        if ($self->cgi->param('callback')) {
            if ($self->format ne "application/json") {
	            $data = { 'data' => $data };
            }
            $self->format("application/json");
            print $self->header;
            print $self->cgi->param('callback')."(".$self->json->encode($data).");";
            exit 0;
        }
        # normal return
        else {
            if ($self->format eq 'application/json') {
                $data = $self->json->encode($data);
            }
            # cache this!
            if ($cache_me) {
                $self->memd->set($self->url_id, $data, $self->{expire});
            }
            # send it
            print $self->header;
            print $data;
            exit 0;
        }
    }
}

# enable hash-resolving in the JSON->encode function
sub TO_JSON { return { %{ shift() } }; }

1;

