classdef (Abstract) Entity < handle
    % ENTITY Classe base astratta per un'entità nella simulazione
    %
    % Ogni entità rappresenta un componente del sistema simulato.
    % Questa classe permette la gestione dello stato e degli handler degli eventi.
    %
    % Proprietà pubbliche:
    % - name : char identificativo univoco dell'entità
    % - state : strutc Stato corrente dell'entità, dipendente dal modello
    % - type : char Tipo o categoria dell'entità
    % - eventHandlers : containers.Map Mappa <nomeEvento, function_handle> 
    %                   per la gestione dinamica degli eventi
    % - info : struct Parametri associati all'entità
    % - intialState : struct Stato iniziale salvato per eventuali reset futuri
    %

    properties
        name char       
        state struct
        type char
        eventHandlers  containers.Map 
        info struct 
        intialState struct 
    end
    
    methods

        %%% Costruttore
        function obj = Entity(name, type, initialState, Info)
            obj.name = name;
            obj.state = initialState;
            obj.type = type;
            obj.eventHandlers = containers.Map();
            if nargin<4, obj.info = struct(); end
            obj.info = Info;
            obj.intialState = initialState;
        end

        %%% GETSTATE 
        % restituisce lo stato corrente dell'entità
        %
        function s = getState(obj)
            s = obj.state;
        end

        %%% SETCONFIG
        % Aggiorna la struct info che contiene i parametri dell'entità
        % config è la struct con i valori nuovi da passare alle entità
        %
        function setConfig(obj, config)
            flds = fieldnames(config);
            for i = 1:numel(flds)
                if isfield(obj.info, flds{i})
                    obj.info.(flds{i}) = config.(flds{i});
                end
            end
        end

        %%% RESETSTATE
        % resetta la struct state riportandola allo stato iniziale
        % 
        function resetState(obj)
            obj.state = obj.intialState;
        end
        
        %%% REGISTERHANDLER
        % Registra un handler per un evento
        %   eventName : char, nome dell'evento
        %   funcHandle : function_handle, funzione da invocare per l'evento
        %   
        function registerHandler(obj, eventName, funcHandle)
            obj.eventHandlers(eventName) = funcHandle;
        end

        %%% HANDLEEVENT 
        % Esegue il gestore di un evento. Un evento può essere eseguito o
        % con un metodo già implementato nella classe entità 
        % (permette di derivare una sottoclasse per un problema specifico 
        % inserendo il metodo per gestire l'evento ) oppure tramite
        % la definizione di una funzione handle.
        % Se registrato, invoca il function handle associato all'evento.
        % Altrimenti cerca un metodo on<EventName>.
        % Se non trovato, genera errore.
        %    
        function handleEvent(obj, event)
            if isKey(obj.eventHandlers, event.name)
                f = obj.eventHandlers(event.name);
                f(obj, event);
            else
                handler = ['on' event.name];
                if ismethod(obj, handler)
                    obj.(handler)(event); 
                else
                    error('%s non gestisce evento %s', obj.name, event.name);
                end
            end
        end

    end 
end 




