unit Uprincipal;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.Buttons, Data.DB,
  Vcl.Grids, Vcl.DBGrids, Vcl.StdCtrls, Vcl.ComCtrls,IdBaseComponent,
  IdComponent, IdTCPConnection, IdTCPClient, IdHTTP, IdIOHandler,
  IdIOHandlerSocket, IdIOHandlerStack, IdSSL, IdSSLOpenSSL, Inifiles, json, ClipBrd,
  Vcl.Imaging.jpeg, IdMessage, IBX.IBCustomDataSet, IBX.IBQuery;

type
  TfrmPrincipal = class(TForm)
    header: TPanel;
    body: TPanel;
    Memo: TMemo;
    DBGridCab: TDBGrid;
    ProgressBar1: TProgressBar;
    DBGrid2: TDBGrid;
    Image1: TImage;
    Label5: TLabel;
    sbtnenviar: TSpeedButton;
    IBQuery1: TIBQuery;
    function EnviarDados(Acao, Dados: String): String;
    function leeRetorno(json, value:string): string;
    function BuscaGrupos(Auxvazio: string):String;
    function BuscaVariacao(AuxTipo: string):String;
    function BuscaProduto(Auxvazio : string):String;
    function EnviarGrupo_Variacao(Tipoenvio: string): Boolean;
    function AtualizaHoraDataEnv(aux,datatime :string): string;

    procedure sbtnenviarClick(Sender: TObject);

  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  frmPrincipal: TfrmPrincipal;
  Pendentes, Endjson, Aux : integer;
  codvarenv,codgrupoenv, codtamenv, apikey : string;
  vIni       : TIniFile;
  host, JsonEnvDados, tipodthratualiza, codgrupo, codtamanho, codbanho : string;

implementation

{$R *.dfm}

uses Udados;

{ TfrmPrincipal }

{ Busca Grupos do produto }
function TfrmPrincipal.AtualizaHoraDataEnv(aux, datatime: string): string;
begin
  with  dados.QryAtualizaEnv do
  begin
    close;
    sql.Clear;
    sql.Add(' update DTHR_ENV_DADOSMACRO dh set ');
    if aux = 'GP' then
      sql.Add(' dh.dthr_gp_env = :datatime ');
    if aux = 'MT' then
      sql.Add(' dh.dthr_bn_env = :datatime ');
    if aux = 'TM' then
      sql.Add(' dh.dthr_tm_env = :datatime ');
    if aux = 'PR' then
    begin
      sql.Add(' dh.dthr_pr_env = :datatime, ');
      sql.Add(' dh.dthr_vr_env = :datatime ');
    end;
    ParamByName('datatime').AsString := datatime;
    Open;
  end;
  Dados.QryAtualizaEnv.Transaction.CommitRetaining;
end;

function TfrmPrincipal.BuscaGrupos(Auxvazio: string): String;
var
  InfoItenJsonGP, ArqJsonGP, ContentJsonGP  : string;
begin
  endjson   := 0;
  Pendentes := 0;
  Aux := 0;
  DBGridCab.DataSource := Dados.dtsbuscavar;
  with Dados.Qrybuscavar do
  begin
    close;
    SQL.Clear;
    SQL.Add(
    ' select distinct '+
    ' g.codigo as grupo, '+
    ' g.descricao as descgrupo '+
    ' FROM grupoproduto g '+
    ' join produto p on p.cod_grupo = g.codigo '+
    ' where g.codigo =:codgrupo '+
    //' and g.hr_imp_macro > (select dh.dthr_gp_env from dthr_env_dadosmacro dh) '+
    ' order by g.codigo ');
    ParamByName('codgrupo').AsString := codgrupo;
    Open;
  end;

  if not (Dados.QryBuscaVar.IsEmpty) then
  begin
    ArqJsonGP := '[{';
    Dados.QryBuscaVar.First;
    while not (Dados.QryBuscaVar.Eof) do
    begin
       Application.ProcessMessages;
       pendentes := pendentes + 1;
       endjson := endjson + 1;
       InfoItenJsonGP := InfoItenJsonGP + '"id":"'+Dados.QryBuscaVar.FieldByName('grupo').AsString+'",';
       InfoItenJsonGP := InfoItenJsonGP + '"id_grupo_pai":"0",';
       InfoItenJsonGP := InfoItenJsonGP + '"descricao":"'+Dados.QryBuscaVar.FieldByName('descgrupo').Text+'",';
       InfoItenJsonGP := InfoItenJsonGP + '"ordem": "1",';
       if endjson > 0 then
          InfoItenJsonGP := InfoItenJsonGP + '"ativo":'+'"1"'+'},{'
       else
          InfoItenJsonGP := InfoItenJsonGP + '"ativo":'+'"1"'+ ',';
       Dados.QryBuscaVar.Next;
    end;
    Aux := length(InfoItenJsonGP) - 3;
    InfoItenJsonGP := Copy(InfoItenJsonGp, 1, Aux);
    ArqJsonGP := ArqJsonGP + InfoItenJsonGP + '}]';
    //ContentJsonGP := '{'+ CabecalhoJson('') +'"dados":'+ ArqJsonGP +'}';
    result := ContentJsonGP +'"dados":'+ArqJsonGP;
  end
  else
    Result := '';
end;

{ Busca Produtos }
function TfrmPrincipal.BuscaProduto(Auxvazio: string): String;
var
  InfoItenJsonPR, InfoItenJsonVR, ArqJsonPR, ArqJsonVR, ContentJsonPR : string;
  endjsonVR, auxVR, pasa : integer;
  dadosEnvJson, vdia, vmes, vano : string;
  qQryAux : TIBQuery;
begin
  Aux := 0;
  endjson   := 0;
  Pendentes := 0;
  qQryAux := TIBQuery.Create(Self);
  with Dados.QryBuscaproduto do
  begin
    close;
    SQL.Clear;
    SQL.Add(' select distinct '+
    ' p.codigo, '+
    ' p.descricao, '+
    ' p.cod_grupo as grupo, '+
    ' p.situacao, '+
    ' p.dteditado, '+
    ' p.hr_imp_macro '+
    ' from linhas_produto L '+
    ' Join Produto P on p.codigo = l.cod_produto '+
    ' where l.site = '+QuotedStr('T')+ 'and p.hr_imp_macro > (select dh.dthr_pr_env from dthr_env_dadosmacro dh) ');
    Open;
  end;

  if dados.QryBuscaproduto.IsEmpty then
  begin
    with Dados.QryBuscaproduto do
    begin
      close;
      SQL.Clear;
      SQL.Add(' select distinct '+
      ' p.codigo, '+
      ' p.descricao, '+
      ' p.cod_grupo as grupo, '+
      ' p.situacao, '+
      ' p.dteditado, '+
      ' p.hr_imp_macro '+
      ' from linhas_produto L '+
      ' Join Produto P on p.codigo = l.cod_produto '+
      ' where l.site = '+QuotedStr('T')+ 'and l.hr_imp_macro > (select dh.dthr_pr_env from dthr_env_dadosmacro dh) ');
      Open;
    end;
  end;


  vdia := Copy(Dados.QryBuscaproduto.FieldByName('dteditado').AsString,0,2);
  vmes := Copy(Dados.QryBuscaproduto.FieldByName('dteditado').AsString,4,2);
  vano := Copy(Dados.QryBuscaproduto.FieldByName('dteditado').AsString,7,7);


  if not (dados.QryBuscaproduto.IsEmpty) then
  begin
     {with qQryAux do
     begin
       Database := dados.IBDatabase;
       Transaction := Dados.IBTransaction;
       Close;
       sql.Clear;
       sql.Add(' select '+
       ' lp.cod_produto, '+
       ' lp.codgeral, '+
       ' lp.codgrupo, '+
       ' lp.estoque, '+
       ' lp.preco, '+
       ' lp.peso, '+
       ' lp.codlinha as codbanho, '+
       ' lp.codvar as codtamanho, '+
       ' lp.situacao '+
       ' from linhas_produto lp '+
       ' where lp.site = '+QuotedStr('T')+ 'and lp.hr_imp_macro > (select dh.dthr_vr_env from dthr_env_dadosmacro dh) ');
       Open;
     end;
     if not qQryAux.IsEmpty then
     begin
        qQryAux.First;
        while not(qQryAux.Eof) do
        begin
          codtamanho := qQryAux.FieldByName('codtamanho').AsString;
          codbanho := qQryAux.FieldByName('codbanho').AsString;
          codgrupo := qQryAux.FieldByName('codgrupo').AsString;
          EnviarGrupo_Variacao('GP');
          EnviarGrupo_Variacao('MT');
          EnviarGrupo_Variacao('TM');
          qQryAux.Next;
        end;
     end;}
    ArqJsonPR := '[{';
    dados.QryBuscaproduto.First;
    while not (dados.QryBuscaproduto.Eof) do
    begin
       Application.ProcessMessages;
       endjson := endjson + 1;
       ShowMessage(dados.QryBuscaproduto.FieldByName('codigo').AsString);
       InfoItenJsonPR := InfoItenJsonPR + '"id":"'+Dados.QryBuscaproduto.FieldByName('codigo').AsString+'",';
       InfoItenJsonPR := InfoItenJsonPR + '"referencia":"'+Dados.QryBuscaproduto.FieldByName('codigo').AsString+'",';
       //InfoItenJsonPR := InfoItenJsonPR + '"descricao_longa":"1",';
       InfoItenJsonPR := InfoItenJsonPR + '"descricao_curta": "'+Dados.QryBuscaproduto.FieldByName('descricao').AsString+'",';
       //InfoItenJsonPR := InfoItenJsonPR + '"observacao": "",';
       InfoItenJsonPR := InfoItenJsonPR + '"criacao": "'+vano+'-'+vmes+'-'+vdia+' '+Dados.QryBuscaproduto.FieldByName('hr_imp_macro').AsString+'",';
       //InfoItenJsonPR := InfoItenJsonPR + '"publicacao": "'+vano+'-'+vmes+'-'+vdia+' '+Dados.QryBuscaproduto.FieldByName('hr_imp_macro').AsString+'",';
       //InfoItenJsonPR := InfoItenJsonPR + '"expiracao": "'+vano+'-'+vmes+'-'+vdia+' '+Dados.QryBuscaproduto.FieldByName('hr_imp_macro').AsString+'",';
       InfoItenJsonPR := InfoItenJsonPR + '"multiplicador": "1",';
       InfoItenJsonPR := InfoItenJsonPR + '"minimo": "1",';
       InfoItenJsonPR := InfoItenJsonPR + '"lancamento": "0",';

       if dados.QryBuscaproduto.FieldByName('situacao').AsString = 'A' then
          InfoItenJsonPR := InfoItenJsonPR + '"ativo": "1",'
       else
          InfoItenJsonPR := InfoItenJsonPR + '"ativo": "0",';
      InfoItenJsonPR := InfoItenJsonPR + '"grupos": ["'+Dados.QryBuscaproduto.FieldByName('grupo').Text+'"],';
         with dados.QrybuscaVariacao do
         begin
            close;
            sql.Clear;
            sql.Add(' select '+
            ' lp.cod_produto, '+
            ' lp.codgeral, '+
            ' lp.codgrupo, '+
            ' lp.estoque, '+
            ' lp.preco, '+
            ' lp.peso, '+
            ' lp.codlinha as codbanho, '+
            ' lp.codvar as codtamanho, '+
            ' lp.situacao '+
            ' from linhas_produto lp '+
            ' where lp.cod_produto  = :codigo '+
            ' and lp.site = '+QuotedStr('T')+ 'and lp.hr_imp_macro > (select dh.dthr_vr_env from dthr_env_dadosmacro dh) ');
            Open;
         end;
         if not dados.QrybuscaVariacao.IsEmpty then
         begin
            ArqJsonVR := '[{';
            dados.QrybuscaVariacao.First;
            { Gerando as Varia�oes para envialo depois }
            endjsonVR := 0;
            InfoItenJsonVR := '';
            while not dados.QrybuscaVariacao.Eof do
            begin
              Application.ProcessMessages;
              endjsonVR := endjsonVR + 1;
              InfoItenJsonVR := InfoItenJsonVR + ' "id_produto_variacao": "'+dados.QrybuscaVariacaoCOD_PRODUTO.AsString+'", ';
              InfoItenJsonVR := InfoItenJsonVR + ' "referencia": "'+dados.QrybuscaVariacaoCODGERAL.AsString+'", ';
              InfoItenJsonVR := InfoItenJsonVR + ' "id_variacao_1": "'+Dados.QrybuscaVariacaoCODBANHO.AsString+'", ';
              InfoItenJsonVR := InfoItenJsonVR + ' "id_variacao_2": "0", ';
              InfoItenJsonVR := InfoItenJsonVR + ' "id_variacao_3": "'+Dados.QrybuscaVariacaoCODTAMANHO.AsString+'", ';
              InfoItenJsonVR := InfoItenJsonVR + ' "fotos": [""], ';
              InfoItenJsonVR := InfoItenJsonVR + ' "estoque": "'+StringReplace(Dados.QrybuscaVariacaoESTOQUE.AsString, ',', '.', [rfReplaceAll])+'", ';
              InfoItenJsonVR := InfoItenJsonVR + ' "peso": "'+StringReplace(Dados.QrybuscaVariacaoPESO.AsString, ',', '.', [rfReplaceAll])+'", ';
              InfoItenJsonVR := InfoItenJsonVR + ' "ordem": "0", ';
              InfoItenJsonVR := InfoItenJsonVR + ' "ativo": "1", ';

              if endjsonVR > 0 then
                InfoItenJsonVR := InfoItenJsonVR + '"precos":'+'[{"id_lista":"1","preco":"'+StringReplace(Dados.QrybuscaVariacaoPRECO.AsString, ',', '', [rfReplaceAll])+'"}]},{'
              else
                InfoItenJsonVR := InfoItenJsonVR + '"precos":'+'[{"id_lista":"1","preco":"'+StringReplace(Dados.QrybuscaVariacaoPRECO.AsString, ',', '', [rfReplaceAll])+'"}]';
              Dados.QrybuscaVariacao.Next;
            end;
            auxVR := Length(InfoItenJsonVR) - 3;
            InfoItenJsonVR := Copy(InfoItenJsonVR, 1, auxVR);
            ArqJsonVR := ArqJsonVR + InfoItenJsonVR + '}]';
            DBGridCab.DataSource := Dados.dtsbuscaproduto;
         end;

       {else
         ArqJsonVR := ''; }


       if ArqJsonVR <> '' then
       begin
        if endjson > 0 then
          InfoItenJsonPR := InfoItenJsonPR + '"variacoes":'+ArqJsonVR+'},{'
        else
          InfoItenJsonPR := InfoItenJsonPR + '"variacoes":'+ArqJsonVR+ ',';
       end
       else
       begin
         if endjson > 0 then
          InfoItenJsonPR := InfoItenJsonPR + '"variacoes":'+'[]'+'},{'
        else
          InfoItenJsonPR := InfoItenJsonPR + '"variacoes":'+'[]'+ ',';
       end;
       dados.QryBuscaproduto.Next;
    end;
    Aux := length(InfoItenJsonPR) - 3;
    InfoItenJsonPR := Copy(InfoItenJsonPR, 1, Aux);
    ArqJsonPR := ArqJsonPR + InfoItenJsonPR + '}]';
    ContentJsonPR := '"dados":'+ ArqJsonPR;
    result := ContentJsonPR;
    tipodthratualiza := 'PR';
  end
  else
  begin
    Application.MessageBox('n�o Foram encontrado penden�as para importar.','Aviso!',MB_ICONWARNING);
    Result := '';
    exit;
  end;
end;

{ Busca Variacao dos produtos }
function TfrmPrincipal.BuscaVariacao(AuxTipo: string): String;
var
  InfoItenJsonVR, ArqJsonVR, ContentJsonVR  : string;
begin
   endjson   := 0;
   Pendentes := 0;
   aux := 0;
  { Busca os Materia ou Banho na tabela linhasproduto }
  DBGridCab.DataSource := Dados.dtsbuscavar;


  { Busca os tamanhos na tabela VARLINHA }
  if AuxTipo = 'TM' then
  begin
    with Dados.QryBuscaVar do
    begin
      close;
      SQL.Clear;
      SQL.Add(' select '+
      ' vln.codigo, '+
      ' vln.descricao '+
      ' from varlinha vln '+
      ' where vln.codigo = :codtamanho '+
      //' and vln.hr_imp_macro > (select dh.dthr_tm_env from dthr_env_dadosmacro dh) '+
      ' order by vln.codigo ');
      ParamByName('codtamanho').AsString := codtamanho;
      Open;
    end;
  end;

  if AuxTipo = 'MT' then
  begin
    with Dados.QryBuscaVar do
    begin
      close;
      SQL.Clear;
      SQL.Add(' select '+
      ' lpd.codigo, '+
      ' lpd.descricao, '+
      ' lpd.ind_linhas as indice '+
      ' from linhasproduto lpd '+
      ' where lpd.codigo = :codbanho '+
      //' and lpd.hr_imp_macro > (select dh.dthr_bn_env from dthr_env_dadosmacro dh) '+
      ' order by lpd.codigo ');
      ParamByName('codbanho').AsString := codbanho;
      Open;
    end;
  end;

  if not (Dados.QryBuscaVar.IsEmpty) then
  begin
    ArqJsonVR := '[{';
    Dados.QryBuscaVar.First;
    while not (Dados.QryBuscaVar.Eof) do
    begin
       Pendentes := Pendentes + 1;
       endjson := endjson + 1;
       InfoItenJsonVR := InfoItenJsonVR + '"id":"'+Dados.QryBuscaVar.FieldByName('codigo').AsString+'",';
       InfoItenJsonVR := InfoItenJsonVR + '"descricao":"'+Dados.QryBuscaVar.FieldByName('descricao').AsString+'",';
       { Caso de que e materia colocar 1 }
       if AuxTipo = 'MT' then
          InfoItenJsonVR := InfoItenJsonVR + '"id_tipo":"1",'
       { Caso de que e tamanho colocar 3 }
       else if AuxTipo = 'TM' then
          InfoItenJsonVR := InfoItenJsonVR + '"id_tipo":"3",'
       { Caso de que nao e materia e tamanho colocar 0 }
       else
          InfoItenJsonVR := InfoItenJsonVR + '"id_tipo":"0",';

       if AuxTipo = 'MT' then
          InfoItenJsonVR := InfoItenJsonVR + '"indice":"'+StringReplace(Dados.QryBuscaVar.FieldByName('indice').AsString, ',', '.', [rfReplaceAll])+'",'
       else
          InfoItenJsonVR := InfoItenJsonVR + '"indice":"0",';

       InfoItenJsonVR := InfoItenJsonVR + '"ordem": "0",';
       if endjson > 0 then
          InfoItenJsonVR := InfoItenJsonVR + '"ativo":'+'"1"'+'},{'
       else
          InfoItenJsonVR := InfoItenJsonVR + '"ativo":'+'"1"'+ ',';
       dados.QryBuscaVar.Next;
    end;
    Aux := length(InfoItenJsonVR) - 3;
    InfoItenJsonVR := Copy(InfoItenJsonVR, 1, Aux);
    ArqJsonVR := ArqJsonVR + InfoItenJsonVR + '}]';
    //ContentJsonVR := '{'+CabecalhoJson('')+'"dados":'+ ArqJsonVR +'}';
    result := ContentJsonVR+'"dados":'+ArqJsonVR;
  end
  else
    Result := '';
end;

function TfrmPrincipal.EnviarDados(Acao, Dados: String): String;
var
  JsonStreamRetorno,JsonStreamEnvio: TStringStream;
  ArqTxt     : TextFile;
  Http       : TIDHttp;
  Sslio      : TIdSSLIOHandlerSocketOpenSSL;
  ts         : TStrings;
  CabDataJson ,vanoret, vmesret, vdiaret, vminutoret, vsegundoret, vhora, vdatahoraretono : string;
begin
  { Buscar dados no config para o envio }
  vIni        := TIniFile.Create(ExtractFilePath(Application.ExeName)+ 'config.ini');
  host        := vIni.ReadString('SERVIDORWEB','host','') ;
  apikey      := vIni.ReadString('SERVIDORWEB','APIKEY','');
  vIni.Free;

  CabDataJson := CabDataJson + '"versao": 1,';
  CabDataJson := CabDataJson + '"data":"2000-01-01 10:20:10",';
  CabDataJson := CabDataJson + '"chave": "'+apikey+'",';
  JsonEnvDados := '{'+ CabDataJson+dados+'}';
  Host        := Host +'/'+acao;
  //para excluir os dados do site
  //host        := 'http://api.emacro.com.br/servicos/limpar_banco';
  Http        := TIdHTTP.Create(nil);
  Sslio       := TIdSSLIOHandlerSocketOpenSSL.Create(nil);
  JsonStreamEnvio := TStringStream.Create(JsonEnvDados, TEncoding.UTF8);
  JsonStreamRetorno := TStringStream.Create('');
  Sslio.Open;
  {try
    Sslio.SSLOptions.Method           := sslvSSLv23;
    Sslio.SSLOptions.Mode             := sslmUnassigned;
    Http.IOHandler                    := SSLIO;
    Http.AllowCookies                 := True;
    Http.HandleRedirects              := True;
    Http.ReadTimeout                  := 50000;
    Http.Request.UserAgent            := 'Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 6.0; Acoo Browser; GTB5; Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1) ; Maxthon; InfoPath.1; .NET CLR 3.5.30729; .NET CLR 3.0.30618)';
    Http.Request.Method               := 'POST';
    Http.Request.ContentEncoding      := 'utf-8';
    Http.Request.BasicAuthentication  := false;
    Http.Request.ContentType          := 'application/json';
    Http.Request.Accept               := 'application/json';

    try
      Application.ProcessMessages;
      try
        Http.Post(host, JsonStreamEnvio, JsonStreamRetorno);
        Result := JsonStreamRetorno.DataString;
        ProgressBar1.StepIt;
      except
        on E:EIdHTTPProtocolException do
        begin
          Result := E.ErrorMessage;
        end;
      end;

      Memo.Clear;
      Memo.Lines.text := Memo.Lines.text + '<----------   Retorno WS   ----------->' + #13;
      Memo.Lines.text := Memo.Lines.text + Result + #13;
      Memo.Lines.text := Memo.Lines.text + '</---------   Retorno WS   ----------->' + #13;
      Memo.Lines.text := Memo.Lines.text + '          ' + #13;
      Memo.Lines.text := Memo.Lines.text + '<---------   String de envio   --------->' + #13;
      Memo.Lines.add(Host + #13 + JsonEnvDados);
      Memo.Lines.text := Memo.Lines.text + '</--------   String de envio   --------->' + #13;

      if leeRetorno(Result,'erro') <> '' then
      begin
        Application.MessageBox(pchar(leeRetorno(Result,'erro')),'Sistema API',MB_ICONERROR);
        exit;
      end
      else
      begin
        leeRetorno(Result,'data');
        vanoret       := copy(leeRetorno(Result,'data'),1,4);
        vmesret       := copy(leeRetorno(Result,'data'), 6, 2);
        vdiaret       := copy(leeRetorno(Result,'data'), 9, 2);

        vhora         := Copy(leeRetorno(Result,'data'), 12, 2);
        vminutoret    := Copy(leeRetorno(Result,'data'), 15, 2);
        vsegundoret   := Copy(leeRetorno(Result,'data'), 18, 2);

        vdatahoraretono :=  vmesret+'/'+vdiaret+'/'+vanoret+' '+vhora+':'+vminutoret+':'+vsegundoret;
        AtualizaHoraDataEnv(tipodthratualiza,vdatahoraretono);
      end;
    finally
      FreeAndNil(JsonStreamEnvio);
    end;
  finally
    FreeAndNil(Http);
  end; }

  ts := TStringList.Create;
  try
    ts.Add(dados);
    Memo.Lines.Add(JsonEnvDados);
    ts.SaveToFile('E:\json_import.txt');
  finally
    ts.Free;
  end;
end;

function TfrmPrincipal.EnviarGrupo_Variacao(Tipoenvio: string): boolean;
var
  retorno, dados : string;
begin
  if tipoenvio = 'GP' then
  begin
    tipodthratualiza := Tipoenvio;
    dados := BuscaGrupos('');
    if (dados <> '') and (Pendentes > 0) then
      retorno := EnviarDados('grupos/criar',dados);
  end
  else
  begin
    tipodthratualiza := Tipoenvio;
    dados := BuscaVariacao(Tipoenvio);
    if (dados <> '') and (Pendentes > 0) then
      retorno := EnviarDados('variacoes/criar',dados);
  end;
end;

function TfrmPrincipal.leeRetorno(json, value: string): string;
var
  LJSONObject: TJSONObject;
  jSubPar: TJSONPair;
   i,j:integer;

begin
   LJSONObject := nil;
   try

      LJSONObject := TJSONObject.ParseJSONValue(TEncoding.ASCII.GetBytes(json),0) as TJSONObject;

      for j := 0 to LJSONObject.Size - 1 do  begin
         jSubPar := LJSONObject.Get(j);  //pega o par no �ndice j
         if (trim(jSubPar.JsonString.Value) = value) then
            Result :=   jSubPar.JsonValue.Value;

      end;
   finally
      LJSONObject.Free;
   end;
end;

procedure TfrmPrincipal.sbtnenviarClick(Sender: TObject);
var
  dadosEnv, retorno : string;
begin
  ProgressBar1.Step := 1;
  ProgressBar1.Min := 0;
  ProgressBar1.Max := 4;
  ProgressBar1.Position := 0;

  dadosEnv := BuscaProduto('');
  if dadosEnv <> '' then
    EnviarDados('produtos/criar',dadosEnv);
end;

end.
