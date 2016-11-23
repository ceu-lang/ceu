GG = {
    , __extcode = (CK'input/output' + CK'output/input') * K'/tight'
                    * OPT(CK'/recursive')
                    * V'__ID_ext' * V'Code_Pars' * KK'=>' * V'Type'
* EE'TODO-PARSER: extcode'
    , _Ext_Code_proto = V'__extcode'
    , _Ext_Code_impl  = V'__extcode' * V'__Do'
    , __extreq = (CK'input/output' + CK'output/input') * K'/await'
                   * OPT('[' * (V'__Exp'+Cc(true)) * KK']')
                   * V'__ID_ext' * V'Code_Pars' * KK'=>' * V'Type'
* EE'TODO-PARSER: request'
    , _Ext_Req_proto = V'__extreq'
    , _Ext_Req_impl  = V'__extreq' * V'__Do'

    , _Emit_ps = OPT(V'__Exp' + PARENS(OPT(V'Explist')))
    , Emit_Ext_call = (K'call/recursive'+K'call') * V'ID_ext' * V'_Emit_ps'
    , Emit_Ext_req  = K'request'                  * V'ID_ext' * V'_Emit_ps'
* EE'TODO-PARSER: request'

    , __det_id = V'ID_ext' + V'ID_int' + V'ID_nat'
    , Deterministic = K'deterministic' * V'__det_id' * (
                        K'with' * LIST(V'__det_id')
                      )^-1

    , Kill  = K'kill' * V'Exp_Name' * OPT(PARENS(V'__Exp'))
