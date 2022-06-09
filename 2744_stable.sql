declare

  v_empresa        number;
  v_sinc_base      number;

  v_tabela         varchar2(100);
  v_chave_tabela   varchar2(4000);  
  
  v_pedido       number;
  v_item_pedido  number;
  v_sequencia    number;
  v_tem          number;
  v_imprime      number;
  v_situacao     number;
  v_op           number;
  
  v_commit       varchar2(5) := 'N';  
  v_retorno               varchar2(2000) := null;
  
 procedure p_chave(p_tabela varchar2, p_chave varchar2) is
   
    v_tmp        long;
    v_campo      varchar2(30);
    v_valor      varchar2(4000);
    v_parametros long;
  
    function f_campo return varchar2 is
   
      v_retorno varchar2(4000);
   
    begin
  
       v_campo := substr(v_tmp,1,instr(v_tmp,'=')-1);
       v_retorno := substr(v_tmp,instr(v_tmp,'=')+1,instr(v_tmp,'&')-instr(v_tmp,'=')-1);
       v_parametros := v_parametros || ' AND ' || v_campo || ' = ' || v_valor;
       v_tmp   := substr(v_tmp,instr(v_tmp,'&')+1,4000);
  
       return v_retorno;
  
    end;
 
  begin
    
    v_tmp := p_chave||'&';
    
    if p_tabela = 'VENPEDIDOEP' then
      
      v_empresa      := f_campo;
      v_pedido       := f_campo;  
      v_item_pedido  := f_campo;
      v_sequencia    := f_campo;  
      
    end if;
        
  end;

begin
    
  delete
    from asdsincdado
   where acao in ('I','D')
	   and id_sinc = (select id 
                      from asdsincroniza
                     where id_sinctabela = 221);    

  select max(id)
    into v_sinc_base
    from asdsincbase
   where upper(descricao) = 'PRAZO_ETAPA';

  for r_sinc in (select asdsinctabela.tabela, 
                        asdsincdado.chave, 
                        asdsincdado.id
                   from asdsincroniza, asdsinctabela, asdsincdado, asdsincbase
                  where asdsincroniza.id_sinctabela = asdsinctabela.id
                    and asdsincroniza.id = asdsincdado.id_sinc
                    and asdsincroniza.id_sincbase = asdsincbase.id
                    and asdsincroniza.tipo = 'A'
                    and asdsincroniza.configurado = 'S'
                    and asdsincdado.acao = 'U'
                    and asdsincdado.executado= 'I'
                    and asdsincroniza.id_sinctabela = 221
                    and asdsincroniza.id_sincbase = v_sinc_base)
  loop
    
    --Limpa Variaveis        
    v_tabela        := r_sinc.tabela;
    v_chave_tabela  := r_sinc.chave;    
  
    p_chave(r_sinc.tabela, r_sinc.chave);
    
    select count(1)
      into v_tem
      from pcpopep
     where empresa = v_empresa
       and pedido = v_pedido
       and item_pedido = v_item_pedido
       and seq_entrega = v_sequencia;
    
    if v_tem > 0 then
    
      select max(op)
        into v_op
        from pcpopep
       where empresa = v_empresa
         and pedido = v_pedido
         and item_pedido = v_item_pedido
         and seq_entrega = v_sequencia;
         
      for r_ops in (select op
                      from pcpop
                     where empresa = v_empresa
                       and op_principal = v_op 
                     union
                    select v_op
                      from dual)
      loop
      
        v_situacao :=0;
        v_imprime  :=0;
    
        select count(1)
          into v_situacao
          from pcpop
         where empresa = v_empresa
           and op = r_ops.op
           and situacao not in ('E','C');
        
        select count(1)
          into v_imprime
          from pcpoprecurso
         where empresa = v_empresa
           and op = r_ops.op
           and imprime <> 'N';
               
        if v_situacao > 0 and v_imprime = 0 then
        
          --atualização de datas de entregas das etapas
          asd.executa_comando('C',2741,'?p_1='||v_empresa||'&p_2='||r_ops.op||'&p_3='||v_commit,'p_4',v_retorno);
           
        end if;  
     
      end loop;    
    
    end if;
      
    delete
      from asdsincdado
     where id      = r_sinc.id
	   and id_sinc = (select id 
                        from asdsincroniza
                       where id_sinctabela = 221); 
    
    commit;
  
  end loop;
  
exception
  when others then
    rollback;
    util.incluir_log_long('INDUSTRIAL', sysdate, 'PRAZO_ETAPA', 'Erro Atualizando Prazo Etapa', ' Tabela '||v_tabela||' Chave: '||v_chave_tabela||' Erro: '||sqlerrm||' - '||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE, 'N');
 
end;
