declare

  p_empresa               cademp.codigo%type := :p_1;
  p_op                    pcpop.op%type      := :p_2;
  p_commit                varchar2(5)        := :p_3;

  v_op_principal          number;
  v_previsao_entrega      date;
  v_entrega_etapa         date;
  v_uf                    varchar2(5)        := 'XX';
  v_regiao                number;
  v_subregiao             number;
  v_tem                   number;

  v_retorno               varchar2(2000)     := null;
  
  --busca a quantidade de dias para a etapa
  function f_busca_dias(v_uf varchar2, v_tipo_recurso number, v_regiao number, v_subregiao number, v_etapa number) return number is
    v_dias number;
  begin

    v_dias := 0;

    --UF do cliente
    /*Desativado na OS 202434
    if v_uf in ('RS', 'SP', 'MS') then
        
      v_dias := 3;
      
    elsif v_uf in ('PR','SC') then
      
      v_dias := 2;
        
    elsif v_uf in ('MG','GO') then
      
      v_dias := 6;
    
    elsif v_uf in ('MT') then
      
      v_dias := 5;
    
    elsif v_uf in ('RO') then
      
      v_dias := 8;
        
    end if;  
    */
    --Região e Subregião do cliente
    if v_regiao = 5 then
        
      v_dias := 1;
      
    elsif v_regiao = 14 then

      if v_subregiao = 1 then
        
        v_dias := 2;
      
      elsif v_subregiao = 2 then
        
        v_dias := 3;
      
      end if;
      
    elsif v_regiao = 18 then

      if v_subregiao = 1 then
        
        v_dias := 2;
      
      elsif v_subregiao = 2 then
        
        v_dias := 3;
      
      end if;
      
    elsif v_regiao = 19 then

      if v_subregiao = 1 then
        
        v_dias := 5;
      
      end if;
        
    elsif v_regiao = 17 then

      if v_subregiao = 1 then
        
        v_dias := 2;
      
      end if;
        
    elsif v_regiao = 6 then

      if v_subregiao = 1 then
        
        v_dias := 3;
      
      end if;
        
    elsif v_regiao = 10 then

      if v_subregiao = 1 then
        
        v_dias := 1;
      
      elsif v_subregiao in (2,3) then
        
        v_dias := 2;
      
      end if;
        
    elsif v_regiao = 25 then

      if v_subregiao = 3 then
        
        v_dias := 2;
      
      elsif v_subregiao in (1,2,4,5) then
        
        v_dias := 1;
      
      end if;
        
    elsif v_regiao = 2 then

      if v_subregiao in (1,2,3,4,5) then
        
        v_dias := 2;
      
      end if;
        
    end if;  

    --tipos de máquinas
    if v_tipo_recurso = 1 then --extrusão
    
      v_dias := 7;
      
    elsif nvl(v_tipo_recurso,0) = 2 then --impressão
        
      v_dias := 5;     
          
    elsif nvl(v_tipo_recurso,0) in (3,8) then --laminação
        
      v_dias := 4;

      if v_etapa = 31 then --se tem etapa de laminação
    
        v_dias := v_dias - 1;
          
      end if;    
          
    elsif v_tipo_recurso in (4,9) then --refiladeira
          
      v_dias := 2;  
          
    elsif v_tipo_recurso = 5 then --corte
          
      v_dias := 2;  
          
    elsif nvl(v_tipo_recurso,0) = 7 then --peliculas
        
      v_dias := 15;     
          
    end if;
      
    return v_dias;
    
  end;
  
  --atualiza
  procedure p_atualiza_entregas(v_op number, v_uf varchar2, v_regiao number, v_subregiao number) is
  begin

    --busca as etapas da OP
    for r_etapa in (select etapa, seq_etapa, tipo_recurso
                      from pcpetapa, pcpopetapa
                     where pcpetapa.empresa = pcpopetapa.empresa
                       and pcpetapa.codigo  = pcpopetapa.etapa
                       and pcpopetapa.empresa = p_empresa
                       and pcpopetapa.op      = v_op
                  order by pcpopetapa.seq_etapa desc) loop
              
      --quando for a última etapa do roteiro      
      if r_etapa.etapa = f_ultima_etapa(p_empresa, null, null, r_etapa.etapa) and r_etapa.tipo_recurso not in (1,7) then
          
        v_entrega_etapa := v_previsao_entrega - f_busca_dias(v_uf, -1, v_regiao, v_subregiao, r_etapa.etapa);

      else
            
        v_entrega_etapa := v_previsao_entrega - f_busca_dias(v_uf, r_etapa.tipo_recurso, v_regiao, v_subregiao, r_etapa.etapa);
           
      end if;      
     
     --dbms_output.put_line(v_op||' - '||r_etapa.etapa||' - Entrega pedido: '||to_char(v_previsao_entrega,'dd/mm/yyyy')||' - Data etapa: '||to_char(v_entrega_etapa,'dd/mm/yyyy'));
     
      --altera a data de entrega da etapa
      update pcpopetapa
         set data_entrega_etapa = v_entrega_etapa
       where empresa    = p_empresa
         and op         = v_op
         and seq_etapa  = r_etapa.seq_etapa;
           
    end loop;
  
  end;  
  
  procedure p_atualiza_op_retrabalho (v_op number) is
  begin
  
    for r_etapa in (select pcpopetapa.seq_etapa,pcpop.data_inc
                      from pcpetapa, pcpopetapa,pcpop
                     where pcpop.empresa = pcpopetapa.empresa
                       and pcpop.op = pcpopetapa.op
                       and pcpetapa.empresa = pcpopetapa.empresa
                       and pcpetapa.codigo  = pcpopetapa.etapa
                       and pcpopetapa.empresa = p_empresa
                       and pcpopetapa.op      = v_op
                  order by pcpopetapa.seq_etapa)
    loop
      
      update pcpopetapa
         set data_entrega_etapa = r_etapa.data_inc + (r_etapa.seq_etapa * 7)
       where empresa    = p_empresa
         and op         = v_op
         and seq_etapa  = r_etapa.seq_etapa;
                   
    end loop;                  
  
  end;
  
begin

  select count(1)
    into v_tem
    from pcpop
   where empresa = p_empresa
     and op = p_op
     and plano is not null;
     
  if v_tem = 0 then   
 
    --busca a OP principal da OP corrente
    select op_principal
      into v_op_principal
      from pcpop
     where empresa = p_empresa
       and op      = p_op;
       
    --quando for OP filha, busca a data da OP principal    
    if v_op_principal is not null then
  
      --busca informações da entrega do pedido atendido 
      select min(previsao_entrega), max(uf), max(cadcorr.regiao), max(cadcorr.subregiao)
        into v_previsao_entrega, v_uf, v_regiao, v_subregiao 
        from cadcidade, cadendereco, cadcorr, venpedido, venpedidoep, pcpopep
       where cadcidade.codigo        = cadendereco.cidade
         and cadendereco.correntista = cadcorr.codigo
         and cadendereco.tipo        = 'L'
         and cadcorr.codigo          = venpedido.cliente
         and venpedido.empresa       = venpedidoep.empresa
         and venpedido.pedido        = venpedidoep.pedido
         and venpedidoep.empresa     = pcpopep.empresa
         and venpedidoep.pedido      = pcpopep.pedido
         and venpedidoep.item_pedido = pcpopep.item_pedido
         and venpedidoep.sequencia   = pcpopep.seq_entrega
         and pcpopep.empresa         = p_empresa
         and pcpopep.op              = v_op_principal;
     
    else 
          
      --busca informações da entrega do pedido atendido 
      select min(previsao_entrega), max(uf), max(cadcorr.regiao), max(cadcorr.subregiao)
        into v_previsao_entrega, v_uf, v_regiao, v_subregiao 
        from cadcidade, cadendereco, cadcorr, venpedido, venpedidoep, pcpopep
       where cadcidade.codigo        = cadendereco.cidade
         and cadendereco.correntista = cadcorr.codigo
         and cadendereco.tipo        = 'L'
         and cadcorr.codigo          = venpedido.cliente
         and venpedido.empresa       = venpedidoep.empresa
         and venpedido.pedido        = venpedidoep.pedido
         and venpedidoep.empresa     = pcpopep.empresa
         and venpedidoep.pedido      = pcpopep.pedido
         and venpedidoep.item_pedido = pcpopep.item_pedido
         and venpedidoep.sequencia   = pcpopep.seq_entrega
         and pcpopep.empresa         = p_empresa
         and pcpopep.op              = p_op;
    
    end if; 
    
    --atualiza as datas de entregas das etapas
    p_atualiza_entregas(p_op, v_uf, v_regiao, v_subregiao);
    
  else
    
    p_atualiza_op_retrabalho(p_op);
    
  end if;
  
  if trim(p_commit) = 'S' then
    commit;
  end if;
  
  :p_4 := v_retorno;
  
exception
  when others then
    rollback;
    :p_4 := 'Erro: '||sqlerrm;  
  
end;
