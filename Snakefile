configfile: "config/config.yaml"
configfile: "config/subset.yaml"
configfile: "config/eems.yaml"
configfile: "config/data.yaml"
configfile: "config/plots.yaml"
configfile: "config/paper.yaml"

subsets = config['paper']
subsets_names = [k for k,v in subsets.items()]
subsets_abbrev = [v['abbrev'] for k,v in subsets.items()]
subsets_paper = [v['main'] for k,v in subsets.items()]
subsets0 = [v['full'] if v['full'] else v['main'] for k,v in subsets.items()]

excluded_sets = []


PLINK_EXT = ['bed', 'bim', 'fam']
META_EXT = ['pop_geo', 'indiv_meta']
INDIV_META_COLS = ['sampleId', 'source', 'used', 
    'originalId', 'permissions', 'popId']
POP_GEO_COLS = ['popId', 'latitude', 'longitude', 'accuracy'] 

PLINK_EXE = config['EXE']['plink']
PLINK_SRC = config['DATA']['genotypes']
_META_ = config['DATA']['meta']
_POP_DISPLAY_ = _META_ + ".pop_display"
_POP_GEO_ = _META_ + ".pop_geo"
_INDIV_META_ = _META_ + ".indiv_meta"


include: 'sfiles/utils.snake'
include: 'sfiles/treemix.snake'
include: 'sfiles/pong.snake'
include: 'sfiles/pca.snake'
include: 'sfiles/spacemix.snake'
include: 'sfiles/paintings.snake'
include: 'sfiles/tess.snake'
include: 'sfiles/fst.snake'
include: 'sfiles/distances.snake'
include: 'sfiles/construct.snake'

base = lambda x: os.path.splitext(x)[0]

def load_subset_config(config, name, verbose=False):
    """ recursively load subset info """
    if verbose:
        print("loading subset %s" % name)

    params = config['__default__'].copy()

    if 'subsets' in config[name]:
        parent_dataset = load_subset_config(config, config[name]['subsets'])
        params.update(parent_dataset)
    params.update(config[name])

    # this bit modifies lists, etc
    if 'modify_parent' in config[name]:
        for k, v in config[name]['modify_parent'].items():
            if k in params:
                params[k] = params[k] + v
            else: 
                params[k] = v
            if verbose:
                print("modifying key %s to value %s" % (k, v))

        
    return params


def snakemake_subsetter(input, output, name):
    """ creates a subset of data based on a geographical region
        see the rule `subset` for an example.
        it assumes that output is in a folder named `subset/`
    input : snakemake.input
        input.bed/bim/fam : a triple of plink format genetic data files
        input.* : a path to pgs-type meta-data
        input.map : path to a shapefile map
    output : snakemake.output
        output.indiv_meta : indiv_meta file of subset
        output.pop_geo: pop_geo file restricted to subset
        output.polygon: a l x 2 file with latitude and longitude
            of polygon points delineating region
    name : str
        the name of the resulting dataset, also, config is read
        from config['subset'][name]
    """
    from subsetter.load import load_pop_geo, load_indiv_meta
    from subsetter.subset.polygon import _get_subset_area, create_polygon_file
    from subsetter.subset import filter_data
    import numpy as np

    outname = base(output.bed)

    params = load_subset_config(config['subset'], name)
    location_data = load_pop_geo(input.pop_geo, wrap=False)
    sample_data = load_indiv_meta(input.indiv_meta)
    meta_data = sample_data.merge(location_data)

    from collections import Counter
    counter = Counter(meta_data.popId)
    pops_to_keep = [c for c in counter if counter[c] >= params['min_sample_size']]
    inds_to_keep = np.in1d(meta_data.popId, pops_to_keep)
    meta_data = meta_data[inds_to_keep]

    if "population" not in params:
        print("POP NOT FOUND WEEE")
        params['population'] = None

    if "region" not in params:
        print("REGION NOT FOUND WEEE")
        params['region'] = None

    if "exclude_pop" not in params:
        print("NO POPS EXCLUDED")
        params['exclude_pop'] = []

    if "filter" in params:
        for f in params["filter"]:
            filter_set = config["filter"][f]
            print("filtering %s" % f)
            params["exclude_pop"].extend(filter_set)


    polygon, meta_data = _get_subset_area(meta_data = meta_data,
        region=params['region'],
        sample_buffer=float(params['sample_buffer']),
        region_buffer=float(params['region_buffer']),
        convex_hull=params['hull'],
        extrema=params['extrema'],
        population=params['population'],
        exclude_pop=params['exclude_pop'],
        exclude_source=params['exclude_source'],
        min_area=params['min_area'],
        add_pop = params['add_pop'],
                _map=input.map)

    # exclucde some individuals
    if 'exclude_samples' in params:
        excl = params['exclude_samples']
        print("excluding stuff, from %s rows ..."% meta_data.shape[0])
        meta_data = meta_data[~meta_data['sampleId'].isin(excl)]
        print("to %s rows ..."% meta_data.shape[0])

    if 'exclude_loci' not in params:
        exclude_loci = []
    else:
        exclude_loci = params['exclude_loci']


    bed = os.path.splitext(input.bed)[0]
    meta_data = filter_data(meta_data=meta_data,
                            bedfile=bed,
                            missing=float(params['max_missing']), 
                            per_ind_missing=float(params['max_missing_ind']),
                            plink=PLINK_EXE,
                            exclude_loci=exclude_loci,
                            max_per_pop=int(params['max_per_pop']),
                            outfile=outname)
    
    meta_data[POP_GEO_COLS].drop_duplicates().to_csv(output.pop_geo, index=False)
    meta_data[INDIV_META_COLS].to_csv(output.indiv_meta, index=False)
    create_polygon_file(polygon, output.polygon, add_outer=False)

def subset_paper_fun(ext, prefix='', subset0=False):
    def ss(wildcards):
        #print('subset_all_fun called')
        subsets = subsets_paper
        if subset0: subsets=subsets0
        infiles = ['%s%s%s' %(prefix, s, ext) for s in subsets 
            if not s == '__default__']
        return infiles
    return ss
    
include: 'sfiles/eems.snake'
include: 'sfiles/eems0.snake'

def subset_all_fun(ext, prefix='', force=False):
    def ss(wildcards):
        #print('subset_all_fun called')
        subsets = config['subset'].keys()
        #print(subsets)
        local_excluded = excluded_sets
        if(force): local_excluded = []
        for s in subsets:
            if s in local_excluded:
                print("excluded " + s)
        infiles = ['%s%s%s' %(prefix, s, ext) for s in subsets 
            if not (s == '__default__' or s in local_excluded)]
        return infiles
    return ss
    

def subset_all_fun_reps(ext, prefix='', nreps=10):
    def ss(wildcards):
        subsets = config['subset'].keys()
        infiles = expand(["".join([prefix, s, ext])  for s in subsets 
            if not s == '__default__'], i=range(nreps))
        return infiles
    return ss
    

include: 'sfiles/paper_figures.snake'



       

# rules that do the data partitioning
def subset_inputfn(wildcards):
    d = dict()
    params = load_subset_config(config['subset'], wildcards.name)
    if 'source_file' in params:
        #print("custom source")
        src = config['DATA']['genotypes']
        #print(src, len(src))
        
        source_file = src[params['source_file']]
    else:
        print("default source")
        source_file = PLINK_SRC
            

    for ext in PLINK_EXT:
        d[ext] = "%s.%s" % (source_file, ext)
    for ext in META_EXT:
        d[ext] = "%s.%s" % (_META_, ext)
    d['map']=config['DATA']['map']
    return d

rule subset_nopca:
    input:
        unpack(subset_inputfn)
    output:
        pop_geo='subset/{name}.pop_geo',
        indiv_meta='subset/{name}.indiv_meta',
        polygon='subset/{name}.polygon',
        bed='subset_nopca/{name}.bed',
        bim='subset_nopca/{name}.bim',
        fam='subset_nopca/{name}.fam',
        incl='subset_nopca/{name}.incl'
    version: "3"
    run:
        snakemake_subsetter(input, output, wildcards.name)

rule subset_pca:
    input:
        bed='subset_nopca/{name}.bed',
        bim='subset_nopca/{name}.bim',
        fam='subset_nopca/{name}.fam',
        outliers="subset/{name}_dim10.outlier_snp"
    output:
        bed='subset/{name}.bed',
        bim='subset/{name}.bim',
        fam='subset/{name}.fam',
    run:
        s = '{PLINK_EXE} --allow-extra-chr --bfile subset_nopca/{wildcards.name} '
        s += ' --out subset/{wildcards.name} --make-bed'
        if 'no_pca' in config['subset'][wildcards.name]:
            if config['subset'][wildcards.name]['no_pca']:
                s += ' --exclude {input.outliers} '
        shell(s)

rule all:
    input:
        subset_paper_fun(prefix="eemsout/", ext=".ifst"),
        subset_paper_fun(prefix='eemsout/0/', ext='/bf.txt'),
        subset_paper_fun(prefix="figures/hwe/", ext=".png"),
        subset_paper_fun(prefix="subset/", ext=".hwemin"),
        subset_paper_fun(prefix="", ext=".figs"),
        subset_paper_fun(prefix="eemsout_gg/", ext="_nruns4-map01.png"),
        subset_paper_fun(prefix="subset/", ext=".fstall"),
        "paper/polygon_plot.pdf",
        'paper/table_sources.csv',
        "paper/table_panel.csv",
        'paper/table_loc.csv',

rule panel_figs:
    input:
        "eemsout_gg/{name}_nruns4-mrates01.png",
        "eemsout_gg/{name}_nruns4-mrates02.png",
        "eemsout_gg/{name}_nruns4-mrates03.png",
        "eemsout_gg/{name}_nruns4-error-grid01.png",
        "eemsout/{name}_nruns4-mrates01.png",
        "figures/pca/2d/{name}_pc1.png",
        "figures/pca/pve/{name}.png",
        "figures/pca/loadings_{name}_pc10.png",
        "subset/{name}_sample_map.png",
        "figures/dists/{name}.png",
        expand("construct/{name}/K{K}.rds", K=[2,3,4,5,6,7,8], name=["{name}"]),
        "pong/run_pong_{name}-K2-8-nruns6.sh",
        expand("treemix/subset/{name}_m0-{i}_runs6.tree.png",name=["{name}"], i=range(6)),
        "tess/subset/{name}_K2-6_nruns3.controller",
    output:
        "{name}.figs"
    shell:
        "touch {output}"

rule spacemix_all:
    input:
        "spacemix/subset/{name}/source_and_target_geospace.png",
        "spacemix/subset/{name}/source_geospace.png",
        "spacemix/subset/{name}/target_geospace.png",
        "spacemix/subset/{name}/no_movement_geospace.png",
    output:
        "{name}.spacefigs"
    shell:
        "touch {output}"

rule eems_only_figs:
    input:
        "eemsout_gg/{name}_nruns4-mrates01.png",
        "eemsout_gg/{name}_nruns4-mrates02.png",
        "eemsout_gg/{name}_nruns4-mrates03.png",
        "eemsout_gg/{name}_nruns4-error-grid01.png",
        "eemsout/{name}_nruns4-mrates01.png",
    output:
        "{name}.efigs"
    shell:
        "touch {output}"
