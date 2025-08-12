classdef Events < handle
    % EVENTS Classe che rappresenta un evento all'interno della simulazione.
    %
    % Questa classe definisce un evento che avviene in un determinato istante
    % temporale e interagisce con una o più entità. L'evento ha la funzione di 
    % orchestrare l'azione, delegando all'entità target la gestione dettagliata 
    % dell'effetto dell'evento sullo stato.
    %
    % Ogni evento possiede un nome, un tempo di accadimento, dati aggiuntivi 
    % e un riferimento all'entità target.
    %
    % Proprietà pubbliche:
    % - name: char  Nome dell'evento
    % - time: double Tempo in cui l'evento si verifica
    % - data:  Dati aggiuntivi associati all'evento (opzionale)
    % - target: Entity Oggetto Entity che deve gestire l'evento
    
    properties
        name char
        time double {mustBeNonnegative} 
        data 
        target % generalizzare ad una lista di entità 
    end

    methods

        %%% Costruttore
        function obj = Events(name, time, data, target)
            if nargin < 3, data = struct(); end
            if nargin < 4, target = []; end
            obj.name = name;
            obj.time = time;
            obj.data = data;
            obj.target = target;
        end

    end
end
