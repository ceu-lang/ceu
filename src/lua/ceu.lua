optparse = dofile 'optparse.lua'

dofile 'dbg.lua'
DBG,ASR = DBG1,ASR1
dofile 'cmd.lua'
if CEU.opts.pre then
    dofile 'pre.lua'
end
if CEU.opts.ceu then
    dofile 'lines.lua'
    dofile 'parser.lua'
    dofile 'ast.lua'
    DBG,ASR = DBG2,ASR2
    dofile 'adjs.lua'
    dofile 'types.lua'
    dofile 'dcls.lua'
    dofile 'names.lua'
    dofile 'exps.lua'
    dofile 'consts.lua'
    dofile 'stmts.lua'
    dofile 'inits.lua'
    dofile 'scopes.lua'
    dofile 'tight_.lua'
    dofile 'props_.lua'
    dofile 'trails.lua'
    dofile 'labels.lua'
    dofile 'vals.lua'
    dofile 'mems.lua'
    dofile 'codes.lua'
end
DBG,ASR = DBG1,ASR1
if CEU.opts.env then
    dofile 'env.lua'
end
if CEU.opts.cc then
    dofile 'cc.lua'
end
--AST.dump(AST.root)
