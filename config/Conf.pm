package Conf;

use Config::Tiny;

$m5nr_collect = "[% m5nr_collect %]";
$m5nr_solr    = "[% m5nr_solr %]";
$m5nr_fasta   = "[% m5nr_fasta %]";
$api_resource_dir  = "resources";
$api_resource_path = "[% api_dir %]/".$api_resource_dir;

if (-s $ENV{"KB_TOP"}.'/deployment.cfg') {
    $kb_cfg = Config::Tiny->read($ENV{"KB_TOP"}.'/deployment.cfg');
    if ($kb_cfg && exists($kb_cfg->{$m5nr_collect})) {
        $m5nr_cfg = $kb_cfg->{$m5nr_collect};
        if (exists($m5nr_cfg->{'SERVICE_PORT'}) && exists($m5nr_cfg->{'SERVICE_HOST'})) {
            $m5nr_solr = $m5nr_cfg->{'SERVICE_PORT'}.':'.$m5nr_cfg->{'SERVICE_HOST'}.'/solr';
        }
        if (exists($m5nr_cfg->{'SERVICE_STORE'})) {
            $m5nr_fasta = $m5nr_cfg->{'SERVICE_STORE'}.'/md5nr';
        }
    }
}
